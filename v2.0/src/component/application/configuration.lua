local File = require("core.file")
local Ini = require("core.ini")
local Configuration = {}
Configuration.__index = Configuration

function Configuration.new(root, paths, publisher, registry)
    return setmetatable(
        { root = assert(root), paths = assert(paths), publisher = assert(publisher), registry = assert(registry) },
        Configuration
    )
end

function Configuration:apply(name)
    local policy = assert(self.registry[name], "unknown_application")
    assert(policy.kind == "ini", "unsupported_configuration")
    local destination = self.paths:resolve(policy.root, policy.destination)
    local file, failure, code = io.open(destination, "rb")
    local current = ""
    if file then
        current = assert(file:read("a"))
        assert(file:close())
    else
        assert(code == 2, failure)
    end
    local result = Ini.merge(File.read(self.root .. "/" .. policy.source), current)
    self.publisher:publish(destination, result, policy.mode)
    return policy.display
end

return Configuration
