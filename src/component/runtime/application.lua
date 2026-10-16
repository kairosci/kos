local File = require("core.file")
local Json = require("core.json")
local Process = require("core.process")
local Catalog = require("core.catalog")
local Menu = require("component.boot.menu")
local Publisher = require("core.publisher")
local Application = {}
Application.__index = Application

function Application.new(root)
    local layout = File.json(root .. "/data/core/layout.json")
    return setmetatable({
        root=root,
        layout=layout,
        process=Process.new(File.json(root .. "/" .. layout.commands)),
        catalog=Catalog.new(File.json(root .. "/" .. layout.locale), root .. "/" .. layout.catalog)
    }, Application)
end

function Application:apply(names, single)
    local Settings = require("component.application.settings")
    local Paths = require("core.paths")
    local Configuration = require("component.application.configuration")
    local registry = File.json(self.root .. "/" .. self.layout.applications)
    local settings = Settings.new(self.root, self.process, registry)
    local paths = Paths.new(File.json(self.root .. "/" .. self.layout.paths))
    local publisher = Publisher.new(self.process)
    local configuration = Configuration.new(self.root, paths, publisher, registry)
    local files = require("component.application.files").new(self.root, paths, publisher, self.process, registry)
    local applications = {}
    if single then applications[1] = assert(names, "application_required")
    else for name in pairs(registry) do applications[#applications + 1] = name end; table.sort(applications) end
    for _, name in ipairs(applications) do
        local policy = assert(registry[name], "unknown_application")
        local application
        if policy.kind == "settings" then application = settings:apply(name)
        elseif policy.kind == "ini" then application = configuration:apply(name)
        elseif policy.kind == "file" or policy.kind == "desktop" then application = files:apply(name)
        else error("unknown_application_kind") end
        io.write(self.catalog:text("gui.install_done", application), "\n")
    end
end

function Application:publish_grub(menu)
    assert(self.process:run("identity"):match("^0%s*$"), "root_required")
    local policy = File.json(self.root .. "/" .. self.layout.bootPolicy)
    local files = File.json(self.root .. "/" .. self.layout.bootFiles)
    local entries = menu:verify(menu:read(File.read(policy.esp .. "/" .. files.inventory)), policy.esp)
    local uuid = self.process:run("mountUuid", {policy.esp}):gsub("\n$", "")
    Publisher.new(self.process):publish(policy.esp .. "/" .. files.menu, menu:render(entries, uuid, policy.menu), files.mode, function(path)
        self.process:run("validateGrub", {path})
    end)
end

function Application:run(arguments)
    local mode, config, esp, uuid, policy_path = table.unpack(arguments)
    if mode == "migration-report" or mode == "verify-full-lua" then
        local inventory = require("component.migration.inventory").new(self.root, self.process, File.json(self.root .. "/" .. self.layout.migration))
        local report = inventory:report()
        io.write(Json.encode(report), "\n")
        if mode == "verify-full-lua" then assert(report.complete, "migration_incomplete") end
        return
    end
    if mode == "render-wallpaper" or mode == "install-wallpapers" then
        local Renderer = require("component.wallpaper.renderer")
        local Paths = require("core.paths")
        local paths = Paths.new(File.json(self.root .. "/" .. self.layout.paths))
        local policy = File.json(self.root .. "/" .. self.layout.wallpaper)
        local renderer = Renderer.new(self.root, self.process, paths, policy, self.catalog)
        if mode == "render-wallpaper" then return renderer:render(config) end
        return require("component.wallpaper.installer").new(renderer):apply()
    end
    if mode == "apply-settings" or mode == "apply-applications" then return self:apply(config, mode == "apply-settings") end
    local menu = Menu.new(self.process, File.json(self.root .. "/" .. self.layout.bootFormat))
    if mode == "publish-grub" then return self:publish_grub(menu) end
    assert((mode == "report" or mode == "grub") and config and esp and (mode ~= "grub" or uuid), "invalid_arguments")
    local entries = menu:verify(menu:read(File.read(config)), esp)
    if mode == "report" then io.write(Json.encode({entries=entries, trialBootVerified=false}), "\n")
    else io.write(menu:render(entries, uuid, File.json(policy_path or self.root .. "/" .. self.layout.bootPolicy).menu)) end
end

function Application:report(failure)
    io.stderr:write(self.catalog:text("runtime.operation_failed", tostring(failure)), "\n")
end

return Application
