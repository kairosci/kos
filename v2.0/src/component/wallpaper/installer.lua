local Installer = {}
Installer.__index = Installer

function Installer.new(renderer)
    return setmetatable({renderer=renderer}, Installer)
end

function Installer:publish()
    local renderer = self.renderer
    return require("core.bundle").new(renderer.root, renderer.process, renderer.paths, renderer.policy):publish()
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
