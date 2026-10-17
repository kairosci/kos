local File = require("core.file")
local Json = require("core.json")
local Session = {}
Session.__index = Session

function Session.new(paths, publisher, policy)
    return setmetatable({ paths = paths, publisher = publisher, policy = policy }, Session)
end

function Session:read()
    local file = self.paths:resolve("config", self.policy.sessionConfiguration)
    local configuration = File.json(file)
    assert(
        type(configuration) == "table" and configuration ~= Json.null and getmetatable(configuration) == nil,
        "invalid_session_configuration"
    )
    return file, configuration
end

function Session:snapshot()
    local _, configuration = self:read()
    local options = Json.array({})
    for _, option in ipairs(self.policy.sessionOptions) do
        local value = configuration
        for _, key in ipairs(option.path) do
            value = type(value) == "table" and value[key] or nil
        end
        local item = {}
        for key, field in pairs(option) do
            item[key] = field
        end
        item.value = value == nil and Json.null or value
        options[#options + 1] = item
    end
    return options
end

function Session:write(key, value)
    local option
    for _, candidate in ipairs(self.policy.sessionOptions) do
        if candidate.key == key then
            option = candidate
            break
        end
    end
    assert(
        option and type(value) == "number" and value % 1 == 0 and value >= option.min and value <= option.max,
        "invalid_session_setting"
    )
    local file, configuration = self:read()
    local parent = configuration
    for index = 1, #option.path - 1 do
        local path = option.path[index]
        if parent[path] == nil then parent[path] = {} end
        assert(
            type(parent[path]) == "table" and parent[path] ~= Json.null and getmetatable(parent[path]) == nil,
            "invalid_session_container"
        )
        parent = parent[path]
    end
    parent[option.path[#option.path]] = value
    self.publisher:publish(file, Json.encode(configuration), self.policy.privateMode)
end

return Session
