local File = require("core.file")
local Json = require("core.json")
local Publisher = require("core.publisher")
local Bundle = {}
Bundle.__index = Bundle

function Bundle.new(root, process, paths, policy)
    return setmetatable({root=root, process=process, paths=paths, policy=policy}, Bundle)
end

function Bundle:optional(path)
    local handle, failure, code = io.open(path, "rb")
    if not handle then assert(code == 2, failure); return nil end
    local content = assert(handle:read("a")); assert(handle:close())
    return content
end

function Bundle:link(target, destination)
    local parent = assert(destination:match("^(.*)/[^/]+$"))
    self.process:run("directory", {parent})
    local staging = self.process:run("temporary", {"-d", parent .. "/.publish.XXXXXXXX"}):gsub("\n$", "")
    local temporary = staging .. "/link"
    local ok, failure = pcall(function()
        self.process:run("symbolicLink", {target, temporary})
        assert(os.rename(temporary, destination))
    end)
    if not ok then
        local handle = io.open(temporary, "rb")
        if handle then assert(handle:close()); assert(os.remove(temporary)) end
    end
    assert(os.remove(staging))
    assert(ok, failure)
end

function Bundle:permissions(directory)
    local policy = self.policy
    if not policy.runtimeDirectoryMode then return end
    local directories = self.process:run("runtimeFiles", {directory .. "/", "-type", "d", "-print0"})
    for path in directories:gmatch("([^%z]+)%z") do self.process:run("permissions", {policy.runtimeDirectoryMode, path}) end
    for _, relative in ipairs(policy.runtimeDirectories) do
        self.process:run("permissions", {policy.runtimeDirectoryMode, self.paths:resolve("data", relative)})
    end
end

function Bundle:publish()
    local process, policy = self.process, self.policy
    local runtime = self.paths:resolve("data", policy.runtime)
    local active = runtime .. "/" .. policy.runtimeCurrent
    local publisher = Publisher.new(process)
    local listing = process:run("runtimeFiles", {"-L", self.root .. "/src", self.root .. "/data", self.root .. "/script", "-type", "f", "-print0"})
    local files, present, unchanged = {}, {}, true
    for _, relative in ipairs(policy.runtimeExtraFiles or {}) do
        assert(relative:sub(1, 1) ~= "/" and not relative:find("..", 1, true), "invalid_runtime_extra_file")
        listing = listing .. self.root .. "/" .. relative .. "\0"
    end
    for source in listing:gmatch("([^%z]+)%z") do
        local relative = source:sub(#self.root + 2)
        present[relative] = true
        local content = File.read(source)
        files[#files + 1] = {relative=relative, content=content, mode=relative:match("^script/") and "755" or policy.mode}
        if self:optional(active .. "/" .. relative) ~= content then unchanged = false end
    end
    assert(#files > 0, "empty_runtime")
    for _, required in ipairs(policy.runtimeRequired) do assert(present[required], "missing_runtime_file_" .. required) end
    table.sort(files, function(left, right) return left.relative < right.relative end)
    local names = Json.array({})
    for _, file in ipairs(files) do names[#names + 1] = file.relative end
    local manifest = Json.encode(names)
    if self:optional(active .. "/" .. policy.runtimeManifest) ~= manifest then unchanged = false end
    if unchanged then
        self:permissions(active)
        return
    end
    process:run("directory", {runtime})
    local stage = process:run("temporary", {"-d", runtime .. "/.release.XXXXXXXX"}):gsub("\n$", "")
    local ok, failure = pcall(function()
        for _, file in ipairs(files) do
            local destination = stage .. "/" .. file.relative
            publisher:publish(destination, file.content, file.mode)
            if file.relative:match("%.lua$") then process:run("validateLua", {destination})
            elseif file.relative:match("%.json$") then File.json(destination) end
        end
        publisher:publish(stage .. "/" .. policy.runtimeManifest, manifest, policy.mode)
        self:permissions(stage)
        self:link(stage, active)
    end)
    if not ok then process:run("removeDirectory", {stage}); error(failure) end
end

return Bundle
