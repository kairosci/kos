local File = require("core.file")
local Settings = {}
Settings.__index = Settings

function Settings.new(root, process, registry)
    return setmetatable({ root = assert(root), process = assert(process), registry = assert(registry) }, Settings)
end

function Settings:apply(name)
    local policy = assert(self.registry[name], "unknown_application")
    assert(policy.kind == "settings", "unsupported_settings")
    local selected
    if policy.schemaSelection then
        local available = "\n" .. self.process:run("gsettings", policy.schemaSelection.command) .. "\n"
        for _, schema in ipairs(policy.schemaSelection.schemas) do
            if available:find("\n" .. schema .. "\n", 1, true) then
                selected = schema
                break
            end
        end
        assert(selected, "unsupported_application_schema")
    end
    local source = File.read(self.root .. "/" .. policy.settings)
    if selected and selected == policy.schemaSelection.original then
        source = source .. "\n" .. File.read(self.root .. "/" .. policy.schemaSelection.legacy)
    end
    local rows, seen = {}, {}
    for line in source:gmatch("[^\r\n]+") do
        local schema, key, value = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)$")
        assert(schema and schema:match("^[%w_.-]+$") and key:match("^[%w-]+$"), "invalid_setting")
        if selected and schema == policy.schemaSelection.original then schema = selected end
        local identity = schema .. ":" .. key
        assert(not seen[identity], "duplicate_setting")
        seen[identity] = true
        rows[#rows + 1] = { "set", schema, key, value }
    end
    assert(#rows > 0, "empty_settings")
    for _, arguments in ipairs(rows) do
        self.process:run("gsettings", arguments)
    end
    return policy.display
end

return Settings
