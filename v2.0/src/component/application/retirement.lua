local File = require("core.file")
local Json = require("core.json")
local Retirement = {}
Retirement.__index = Retirement

function Retirement.new(paths, publisher, process, registry)
    return setmetatable({ paths = paths, publisher = publisher, process = process, registry = registry }, Retirement)
end

function Retirement:optional(path)
    local linked = self.process:status("isLink", { path })
    assert(linked == 1, linked == 0 and "redirected_application_path" or "path_probe_failed")
    local file, failure, code = io.open(path, "rb")
    if not file then
        assert(code == 2, failure)
        return nil
    end
    assert(file:close())
    return path
end

function Retirement:apply(name)
    local policy = assert(self.registry[name], "unknown_application")
    for _, relative in ipairs(policy.guards or {}) do
        self:optional(self.paths:resolve("config", relative))
    end
    local path = self.paths:resolve("config", policy.configuration)
    local existing = self:optional(path)
    local configuration
    if existing then
        configuration = File.json(existing)
        assert(
            type(configuration) == "table" and configuration ~= Json.null and getmetatable(configuration) == nil,
            "invalid_application_object"
        )
        if policy.kind == "retirement" then
            for _, key in ipairs(policy.removeKeys) do
                configuration[key] = nil
            end
        elseif policy.kind == "json-provider" then
            local layout = configuration
            for _, key in ipairs(policy.container) do
                layout = type(layout) == "table" and layout[key] or nil
            end
            if type(layout) == "table" and getmetatable(layout) == nil then
                for _, entries in pairs(layout) do
                    assert(type(entries) == "table", "invalid_provider_entries")
                    for index, entry in ipairs(entries) do
                        if entry == policy.identity then
                            entry = { [policy.identityKey] = entry }
                            entries[index] = entry
                        end
                        if type(entry) == "table" and entry[policy.identityKey] == policy.identity then
                            local parent = entry
                            for offset = 1, #policy.assign - 1 do
                                local key = policy.assign[offset]
                                if parent[key] == nil then parent[key] = {} end
                                assert(type(parent[key]) == "table", "invalid_provider_configuration")
                                parent = parent[key]
                            end
                            parent[policy.assign[#policy.assign]] = policy.value
                        end
                    end
                end
            end
        else
            error("unsupported_retirement_policy")
        end
    end
    if policy.removeTree then
        local tree = self.paths:resolve("config", policy.removeTree)
        if self:optional(tree) then self.process:run("removeDirectory", { tree }) end
    end
    if configuration then self.publisher:publish(path, Json.encode(configuration), policy.mode) end
    return policy.display
end

return Retirement
