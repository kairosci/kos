local File = require("core.file")
local Json = require("core.json")
local Publisher = require("core.publisher")
local Installer = {}
Installer.__index = Installer

function Installer.new(renderer)
    return setmetatable({renderer=renderer}, Installer)
end

function Installer:publish()
    local renderer = self.renderer
    local process, policy = renderer.process, renderer.policy
    local runtime = renderer.paths:resolve("data", policy.runtime)
    local active = runtime .. "/" .. policy.runtimeCurrent
    local publisher = Publisher.new(process)
    local listing = process:run("runtimeFiles", {renderer.root .. "/src", renderer.root .. "/data", renderer.root .. "/script", "-type", "f", "-print0"})
    local files, unchanged = {}, true
    for source in listing:gmatch("([^%z]+)%z") do
        local relative = source:sub(#renderer.root + 2)
        local content = File.read(source)
        files[#files + 1] = {relative=relative, content=content, mode=relative:match("^script/") and "755" or policy.mode}
        if renderer:optional(active .. "/" .. relative) ~= content then unchanged = false end
    end
    assert(#files > 0, "empty_runtime")
    table.sort(files, function(left, right) return left.relative < right.relative end)
    local names = Json.array({})
    for _, file in ipairs(files) do names[#names + 1] = file.relative end
    local manifest = Json.encode(names)
    if renderer:optional(active .. "/" .. policy.runtimeManifest) ~= manifest then unchanged = false end
    if unchanged then return end
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
        renderer:link(stage, active)
    end)
    if not ok then process:run("removeDirectory", {stage}); error(failure) end
end

function Installer:apply()
    local renderer = self.renderer
    local process, policy = renderer.process, renderer.policy
    self:publish()
    local retired = renderer.paths:resolve("data", policy.retiredRuntime)
    if renderer:optional(retired) then assert(os.remove(retired)) end
    local platform = renderer.getenv(policy.platformVariable)
    if not platform or platform == "" then platform = policy.platformRoot end
    local directories = process:run("runtimeFiles", {platform .. "/" .. policy.themes, "-mindepth", "1", "-maxdepth", "1", "-type", "d", "-print0"})
    local custom = renderer.paths:resolve("config", policy.userThemes)
    process:run("directory", {custom})
    directories = directories .. process:run("runtimeFiles", {custom, "-mindepth", "1", "-maxdepth", "1", "-type", "d", "-print0"})
    local themes = {}
    for directory in directories:gmatch("([^%z]+)%z") do
        if renderer:optional(directory .. "/" .. policy.colors) then themes[assert(directory:match("([^/]+)$"))] = true end
    end
    for theme in pairs(themes) do renderer:render(theme) end
end

return Installer
