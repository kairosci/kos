local File = require("core.file")
local Blocks = require("core.blocks")
local Gtk = {}
Gtk.__index = Gtk

function Gtk.new(root, paths, publisher, process, registry)
    return setmetatable({root=root, paths=paths, publisher=publisher, process=process, registry=registry}, Gtk)
end

local function read_sources(root, policy, process)
    local sources = {
        {policy.adapterSource, policy.adapterDestination, "config", "644"},
        {policy.paletteSource, policy.paletteDestination, "data", "644"}
    }
    local files = {}
    local listed, status = process:capture("findFiles", {root .. "/" .. policy.iconSource, "-maxdepth", "1", "-type", "f", "-print0"})
    assert(status == 0, "gtk_icon_inventory_failed")
    for path in listed:gmatch("[^%z]+") do files[#files + 1] = path end
    table.sort(files)
    assert(#files > 0, "gtk_icon_inventory_empty")
    for _, path in ipairs(files) do
        local name = assert(path:match("([^/]+)$"), "gtk_icon_name_invalid")
        sources[#sources + 1] = {path:sub(#root + 2), policy.iconDestination .. "/" .. name, "config", "644"}
    end
    local content = {}
    for _, item in ipairs(sources) do content[#content + 1] = {item[1], item[2], item[3], item[4], File.read(root .. "/" .. item[1])} end
    return content
end

function Gtk:archive(path, target, expected)
    local source = self.paths:resolve("config", path)
    local content = self.publisher:inspect(source)
    if not content or not content:find(expected, 1, true) then return end
    self.publisher:publish(self.paths:resolve("config", target), content, "644")
    self.process:run("removeFile", {source})
end

function Gtk:retire_legacy(policy)
    local hook = self.paths:resolve("config", policy.legacyHook)
    local content = self.publisher:inspect(hook)
    if content and content:find(policy.legacyHookCommand, 1, true) then
        self:archive(policy.legacyHook, policy.legacyHookArchive, policy.legacyHookCommand)
        local generator = self.paths:resolve("config", policy.legacyGenerator)
        local generatorContent = self.publisher:inspect(generator)
        if generatorContent then
            self.publisher:publish(self.paths:resolve("config", policy.legacyGeneratorArchive), generatorContent, "644")
            self.process:run("removeFile", {generator})
        end
        self:archive(policy.legacyUpdate, policy.legacyUpdateArchive, policy.legacyUpdateCommand)
    end
end

function Gtk:apply(name)
    local policy = assert(self.registry[name], "unknown_application")
    assert(policy.kind == "gtk", "unsupported_gtk_integration")
    local sources = read_sources(self.root, policy, self.process)
    local roots = {config=self.paths:resolve("config", ""), data=self.paths:resolve("data", "")}
    for _, relative in ipairs({policy.adapterDestination:match("^(.*)/[^/]+$"), policy.iconDestination, policy.legacyHook:match("^(.*)/[^/]+$"), policy.legacyHookArchive:match("^(.*)/[^/]+$"), policy.legacyGenerator:match("^(.*)/[^/]+$"), policy.legacyGeneratorArchive:match("^(.*)/[^/]+$"), policy.legacyUpdate:match("^(.*)/[^/]+$"), policy.legacyUpdateArchive:match("^(.*)/[^/]+$")}) do
        self.paths:guardDirectory(self.process, roots.config, relative)
    end
    self.paths:guardDirectory(self.process, roots.data, policy.paletteDestination:match("^(.*)/[^/]+$"))
    local settings = require("component.application.settings").new(self.root, self.process, {
        [name]={kind="settings", settings=policy.settings, display=policy.display}
    })
    local content = self.publisher:inspect(self.paths:resolve("config", policy.hyprland))
    local mode = "644"
    if content then
        local _, permissions = self.publisher:inspect(self.paths:resolve("config", policy.hyprland))
        mode = string.format("%o", permissions & 0xFFF)
    end
    local block = content and Blocks.merge(content, policy.first, policy.last, policy.body) or nil
    for _, item in ipairs(sources) do
        local destination = self.paths:resolve(item[3], item[2])
        self.publisher:publish(destination, item[5], item[4])
    end
    if block then self.publisher:publish(self.paths:resolve("config", policy.hyprland), block, mode) end
    self:retire_legacy(policy)
    settings:apply(name)
    return policy.display
end

return Gtk
