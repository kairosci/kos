local File = require("core.file")
local Json = require("core.json")
local Paths = require("core.paths")
local Publisher = require("core.publisher")
local Bundle = require("core.bundle")
local Installer = {}
Installer.__index = Installer

function Installer.new(root, process, policy, paths)
    return setmetatable(
        { root = root, process = process, policy = policy, paths = paths, publisher = Publisher.new(process) },
        Installer
    )
end

function Installer:check(destination)
    local policy, process = self.policy, self.process
    local linked = process:status("isLink", { destination })
    assert(linked == 0 or linked == 1, "link_probe_failed")
    if linked == 0 then
        local previous = process:run("readLink", { destination }):gsub("\n$", "")
        assert(
            previous:sub(1, #policy.systemDataRoot + 1) == policy.systemDataRoot .. "/"
                or previous == policy.systemExecutable,
            "unmanaged_cli_link"
        )
        return "link", previous
    end
    local handle, failure, code = io.open(destination, "rb")
    if handle then
        local content = assert(handle:read("a"))
        assert(handle:close())
        assert(content:find(policy.managedSignature, 1, true), "unmanaged_cli_executable")
        return "file", content
    end
    assert(code == 2, failure)
end

function Installer:link(target, destination)
    local kind, previous = self:check(destination)
    if kind == "link" then
        if previous == target then return end
        self.publisher:publish(
            destination .. self.policy.backupSuffix .. ".json",
            Json.encode({ target = previous }),
            "600"
        )
    elseif kind == "file" then
        self.publisher:publish(destination .. self.policy.backupSuffix, previous, self.policy.executableMode)
    end
    Bundle.new(self.root, self.process, self.paths, self.policy):link(target, destination)
end

function Installer:system()
    local policy, process = self.policy, self.process
    assert(process:run("identity"):match("^0%s*$"), "root_required")
    local paths = Paths.new(File.json(self.root .. "/data/core/paths.json"), function(name)
        if name == "XDG_DATA_HOME" then return policy.systemDataRoot end
        return os.getenv(name)
    end)
    self:check(policy.systemExecutable)
    local bundle = Bundle.new(self.root, process, paths, policy)
    bundle:publish()
    local active = paths:resolve("data", policy.runtime) .. "/" .. policy.runtimeCurrent
    self:link(active .. "/" .. policy.entrypoint, policy.systemExecutable)
    self.publisher:publish(policy.systemChangelog, File.read(self.root .. "/CHANGELOG.md"), policy.mode)
    for _, item in ipairs(policy.legacyFiles) do
        self.publisher:publish(item.destination, File.read(self.root .. "/" .. item.source), policy.mode)
    end
    local locale = File.json(self.root .. "/data/core/locale.json")
    for _, language in ipairs(locale.languages) do
        self.publisher:publish(
            policy.legacyCatalogDirectory .. "/" .. language .. ".msg",
            File.read(self.root .. "/data/catalog/" .. language .. ".msg"),
            policy.mode
        )
    end
end

function Installer:user()
    local paths = assert(self.paths, "user_paths_required")
    self:link(self.policy.systemExecutable, paths:resolve("home", self.policy.userExecutable))
    self.publisher:publish(
        paths:resolve("data", self.policy.userChangelog),
        File.read(self.root .. "/CHANGELOG.md"),
        self.policy.mode
    )
end

return Installer
