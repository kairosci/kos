local File = require("core.file")
local Json = require("core.json")
local Panel = {}
Panel.__index = Panel

function Panel.new(root, paths, publisher, registry, environment)
    return setmetatable(
        { root = root, paths = paths, publisher = publisher, registry = registry, getenv = environment or os.getenv },
        Panel
    )
end

function Panel.literal(value)
    return (value:gsub("([^%w])", "%%%1"))
end

function Panel:apply(name)
    local policy = assert(self.registry[name], "unknown_application")
    local upstream = self.getenv(policy.sourceVariable)
    if not upstream or upstream == "" then upstream = policy.sourceDefault end
    assert(upstream:sub(1, 1) == "/", "absolute_panel_source_required")
    local source = upstream .. "/" .. policy.source
    local payload = {}
    for _, file in ipairs(policy.files) do
        payload[file] = File.read(source .. "/" .. file)
    end
    for _, patch in ipairs(policy.patches) do
        local content = assert(payload[patch.file], "unknown_panel_patch_file")
        local count = 0
        for line in (content .. "\n"):gmatch("([^\n]*)\n") do
            if line == patch.anchor then count = count + 1 end
        end
        assert(count == 1, "unsupported_native_panel")
        if patch.insert then
            local addition = File.read(self.root .. "/" .. patch.insert):gsub("\n$", "")
            content = content:gsub(Panel.literal(patch.anchor), function()
                return patch.anchor .. "\n" .. addition
            end)
        else
            content = content:gsub(Panel.literal(patch.anchor), function()
                return patch.replacement
            end)
        end
        for _, substitution in ipairs(patch.substitutions or {}) do
            content = content:gsub(Panel.literal(substitution.from), function()
                return substitution.to
            end)
        end
        payload[patch.file] = content
    end
    local manifest = Json.decode(assert(payload[policy.manifest]))
    assert(
        type(manifest) == "table" and manifest ~= Json.null and getmetatable(manifest) == nil,
        "invalid_panel_manifest"
    )
    assert(manifest.id == policy.original, "unexpected_panel_identity")
    manifest.id = policy.identity
    if manifest.omarchy == nil then manifest.omarchy = {} end
    assert(
        type(manifest.omarchy) == "table" and manifest.omarchy ~= Json.null and getmetatable(manifest.omarchy) == nil,
        "invalid_panel_metadata"
    )
    manifest.omarchy.clonedFrom = policy.original
    payload[policy.manifest] = Json.encode(manifest)
    local configurationPath = self.paths:resolve("config", policy.configuration)
    local configuration = File.json(configurationPath)
    assert(
        type(configuration) == "table" and configuration ~= Json.null and getmetatable(configuration) == nil,
        "invalid_panel_configuration"
    )
    local function rewrite(value)
        if type(value) ~= "table" or value == Json.null then return end
        if value.id == policy.original then value.id = policy.identity end
        for _, child in pairs(value) do
            rewrite(child)
        end
    end
    rewrite(configuration)
    for _, file in ipairs(policy.files) do
        self.publisher:publish(
            self.paths:resolve("config", policy.destination .. "/" .. file),
            payload[file],
            policy.mode
        )
    end
    self.publisher:publish(configurationPath, Json.encode(configuration), policy.privateMode)
    return policy.display
end

return Panel
