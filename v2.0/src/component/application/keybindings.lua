local File = require("core.file")
local Blocks = require("core.blocks")
local Keybindings = {}
Keybindings.__index = Keybindings

function Keybindings.new(root, paths, publisher, process, catalog, registry)
    return setmetatable({root=root, paths=paths, publisher=publisher, process=process, catalog=catalog, registry=registry}, Keybindings)
end

function Keybindings:apply(name)
    local policy = assert(self.registry[name], "unknown_application")
    assert(policy.kind == "keybindings", "unsupported_keybindings")
    local menu = self.paths:resolve("data", policy.menuDestination)
    self.paths:guardDirectory(self.process, self.paths:resolve("data", ""), policy.menuDestination:match("^(.*)/[^/]+$"))
    self.publisher:publish(menu, File.read(self.root .. "/" .. policy.menuSource), policy.menuMode)

    local destination = self.paths:resolve("config", policy.bindings)
    self.paths:guardDirectory(self.process, self.paths:resolve("config", ""), policy.bindings:match("^(.*)/[^/]+$"))
    local existing = self.publisher:inspect(destination)
    if not existing then
        io.stderr:write(self.catalog:text("herdr.bind_skipped", self.paths:resolve("home", "")), "\n")
        return policy.display
    end
    local quotedMenu = menu:gsub("\\", "\\\\"):gsub('"', '\\"')
    local body = policy.body:format(quotedMenu)
    self.publisher:publish(destination, Blocks.merge(existing, policy.first, policy.last, body), policy.mode)
    return policy.display
end

return Keybindings
