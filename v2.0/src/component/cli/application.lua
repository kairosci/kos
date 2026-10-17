local File = require("core.file")
local Json = require("core.json")
local Cli = {}
Cli.__index = Cli

function Cli.new(root, process, catalog, policy, environment, output)
    return setmetatable({root=root, process=process, catalog=catalog, policy=policy, getenv=environment or os.getenv, output=output or io.stdout}, Cli)
end

function Cli:message(key, ...)
    error(self.catalog:text(key, ...), 0)
end

function Cli:optional(path)
    local handle, failure, code = io.open(path, "rb")
    if not handle then assert(code == 2, failure); return nil end
    local content = assert(handle:read("a")); assert(handle:close())
    return content
end

function Cli:session()
    local values = {}
    local uid = self.process:run("identity"):match("^(%d+)%s*$")
    assert(uid, "invalid_user_identity")
    local directory = self.policy.runtimeDirectory:format(uid)
    if (not self.getenv("XDG_RUNTIME_DIR") or self.getenv("XDG_RUNTIME_DIR") == "") and self.process:status("isDirectory", {directory}) == 0 then values.XDG_RUNTIME_DIR = directory end
    if (not self.getenv("DBUS_SESSION_BUS_ADDRESS") or self.getenv("DBUS_SESSION_BUS_ADDRESS") == "") and self.process:status("isSocket", {directory .. "/bus"}) == 0 then values.DBUS_SESSION_BUS_ADDRESS = "unix:path=" .. directory .. "/bus" end
    local arguments, keys = {}, {}
    for key in pairs(values) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do arguments[#arguments + 1] = key .. "=" .. values[key] end
    return arguments
end

function Cli:executable(name)
    for directory in ((self.getenv("PATH") or "") .. ":"):gmatch("([^:]*):") do
        local candidate = directory .. "/" .. name
        if directory ~= "" and self.process:status("isExecutable", {candidate}) == 0 and self.process:status("isDirectory", {candidate}) == 1 then return candidate end
    end
end

function Cli:desktop_path(id)
    local policy = self.policy
    local home = assert(self.getenv("HOME"), "home_required")
    local dataHome = self.getenv("XDG_DATA_HOME")
    if not dataHome or dataHome == "" then dataHome = home .. "/" .. policy.dataHomeRelative end
    local dataDirectories = self.getenv("XDG_DATA_DIRS")
    if not dataDirectories or dataDirectories == "" then dataDirectories = policy.dataDirectories end
    local directories = {dataHome}
    for directory in (dataDirectories .. ":"):gmatch("([^:]*):") do directories[#directories + 1] = directory end
    for _, directory in ipairs(directories) do
        local base = directory .. "/" .. policy.applicationDirectory
        if directory:sub(1, 1) == "/" and self.process:status("isDirectory", {base}) == 0 then
            local direct = base .. "/" .. id
            if self:optional(direct) then return direct end
            local found
            for file in self.process:run("runtimeFiles", {base, "-mindepth", "2", "-name", "*.desktop", "-type", "f", "-print0"}):gmatch("[^%z]+") do
                if file:sub(#base + 2):gsub("/", "-") == id then
                    assert(not found, "ambiguous_desktop_identifier")
                    found = file
                end
            end
            if found then return found end
        end
    end
end

function Cli.desktop(content)
    local sections, section = {}, nil
    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        local clean = line:gsub("\r$", "")
        local heading = clean:match("^%[(.+)%]$")
        if heading then
            assert(not sections[heading], "duplicate_desktop_section")
            sections[heading] = {}; section = sections[heading]
        elseif section then
            local key, value = clean:match("^([^=#][^=]*)=(.*)$")
            if key then assert(section[key] == nil, "duplicate_desktop_field"); section[key] = value end
        end
    end
    return sections
end

function Cli:app(arguments)
    local index, resolve = 1, false
    if arguments[index] == "--resolve" then resolve = true; index = index + 1 end
    local role = arguments[index]
    if not role or role == "--help" then self.output:write(self.catalog:text("os.app_usage"), "\n"); return 0 end
    local roles = File.json(self.root .. "/" .. self.policy.roles)
    local selection = roles[role]
    if not selection then self:message("os.app_invalid", role) end
    local desktop
    if selection.selector == "browser" then
        desktop = self.process:run("environment", self.policy.browserCommand):gsub("\n$", "")
        if desktop == "" then
            local query = {}; for _, word in ipairs(self.policy.mimeCommand) do query[#query + 1] = word end
            query[#query + 1] = assert(selection.fallbackMime)
            desktop = self.process:run("environment", query):gsub("\n$", "")
        end
    elseif selection.selector == "mime" then
        local query = {}; for _, word in ipairs(self.policy.mimeCommand) do query[#query + 1] = word end
        query[#query + 1] = assert(selection.mime)
        desktop = self.process:run("environment", query):gsub("\n$", "")
    elseif selection.selector == "desktop" then desktop = selection.desktop
    else error("invalid_application_selector") end
    if type(desktop) ~= "string" or not desktop:match("^[%a%d][%w_.-]*%.desktop$") then self:message("os.app_default_missing", role) end
    local path = self:desktop_path(desktop)
    if not path then self:message("os.app_default_missing", role) end
    local sections = Cli.desktop(File.read(path))
    local main = sections["Desktop Entry"]
    if not main or main.Type ~= "Application" or main.Hidden == "true" then self:message("os.app_default_missing", role) end
    local private, values = false, {}
    for offset = index + 1, #arguments do
        local argument = arguments[offset]
        if role == "browser" and argument == "--private" then private = true
        elseif argument:sub(1, 1) == "-" then self:message("os.app_invalid", argument)
        else values[#values + 1] = argument end
    end
    if private then
        local action = assert(selection.privateAction, "missing_private_action")
        assert(action:match("^[%a][%w_-]*$"), "invalid_private_action")
        local declared = false
        for item in (main.Actions or ""):gmatch("[^;]+") do if item == action then declared = true end end
        local command = sections["Desktop Action " .. action]
        if not declared or not command or not command.Exec or command.Exec == "" then self:message("os.app_private_missing", desktop) end
        desktop = desktop .. ":" .. action
    end
    local argv = Json.array({self.policy.launcher, "--", desktop})
    if not self:executable(self.policy.launcher) then self:message("os.app_dependency_missing", self.policy.launcher) end
    for _, value in ipairs(values) do argv[#argv + 1] = value end
    if resolve then
        self.output:write(Json.encode({role=role, desktop=desktop, desktopFile=path, private=private, argv=argv}), "\n")
        return 0
    end
    local environment = self:session()
    for _, value in ipairs(argv) do environment[#environment + 1] = value end
    return self.process:status("environment", environment)
end

function Cli:changelog(release)
    local policy, content, source = self.policy
    local candidates = {}
    local override = self.getenv(policy.changelogVariable)
    if override and override ~= "" then candidates[#candidates + 1] = override end
    candidates[#candidates + 1] = self.root .. "/" .. policy.changelog
    candidates[#candidates + 1] = policy.systemChangelog
    candidates[#candidates + 1] = assert(self.getenv("HOME"), "home_required") .. "/" .. policy.userChangelog
    for _, path in ipairs(candidates) do
        content = self:optional(path)
        if content then source = path; break end
    end
    if not source then self:message("os.changelog_missing", candidates[1]) end
    if not release then self.output:write(content); return 0 end
    local tag
    if release:lower() == "unreleased" then tag = "## Unreleased"
    else tag = "## Release " .. (release:sub(1, 1) == "v" and release or "v" .. release) end
    local output, active = {}, false
    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        if line == tag then active = true
        elseif active and line:match("^## ") then break end
        if active then output[#output + 1] = line end
    end
    if #output == 0 then self:message("os.changelog_unknown", release) end
    self.output:write(table.concat(output, "\n"):gsub("\n*$", ""), "\n")
    return 0
end

function Cli:runtime(arguments)
    local policy = self.policy
    local runtime = self.getenv(policy.runtimeVariable)
    if not runtime or runtime == "" then runtime = policy.runtimeDefault end
    assert(runtime:sub(1, 1) == "/", "absolute_runtime_required")
    local environment = self:session()
    environment[#environment + 1] = policy.runtimeVariable .. "=" .. runtime
    local executable = policy.runtimeCommand
    local found = self:executable(executable)
    if not found then
        executable = runtime .. "/" .. policy.runtimeExecutable
        if self.process:status("isExecutable", {executable}) ~= 0 then self:message("os.runtime_missing") end
    end
    environment[#environment + 1] = executable
    for _, word in ipairs(arguments) do environment[#environment + 1] = word end
    if arguments[1] == "version" then
        self.output:write(self.catalog:text("os.dispatcher_version", policy.version), "\n")
        self.output:write(self.process:run("environment", environment))
        self.output:write(File.read(runtime .. "/" .. policy.runtimeVersion))
        return 0
    end
    return self.process:status("environment", environment)
end

function Cli:run(arguments)
    local first = arguments[1]
    if not first then
        io.stderr:write(File.read(self.root .. "/" .. self.policy.help:format(self.catalog.language)))
        self:message("os.dispatch_failed", "")
    end
    if first == "--help" or first == "-h" or first == "help" then self.output:write(File.read(self.root .. "/" .. self.policy.help:format(self.catalog.language))); return 0 end
    if first == "changelog" then return self:changelog(arguments[2]) end
    if first == "--version" then arguments[1] = "version" end
    if first == "app" then
        local remaining = {}; for index = 2, #arguments do remaining[#remaining + 1] = arguments[index] end
        return self:app(remaining)
    end
    return self:runtime(arguments)
end

return Cli
