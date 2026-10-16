local File = require("core.file")
local Settings = {}
Settings.__index = Settings

function Settings.new(root, process, registry)
    return setmetatable({root=assert(root), process=assert(process), registry=assert(registry)}, Settings)
end

function Settings:apply(name)
    local policy = assert(self.registry[name], "unknown_application")
    assert(policy.kind == "settings", "unsupported_settings")
    local rows, seen = {}, {}
    for line in File.read(self.root .. "/" .. policy.settings):gmatch("[^\r\n]+") do
        local schema, key, value = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)$")
        assert(schema and schema:match("^[%w_.-]+$") and key:match("^[%w-]+$"), "invalid_setting")
        local identity = schema .. ":" .. key
        assert(not seen[identity], "duplicate_setting")
        seen[identity] = true
        rows[#rows + 1] = {"set", schema, key, value}
    end
    assert(#rows > 0, "empty_settings")
    for _, arguments in ipairs(rows) do self.process:run("gsettings", arguments) end
    return policy.display
end

return Settings
