local File = require("core.file")
local Catalog = {}
Catalog.__index = Catalog

function Catalog.new(policy, directory, environment)
    local getenv = environment or os.getenv
    local candidate
    for _, name in ipairs(policy.environment) do
        local value = getenv(name)
        if value and value ~= "" and value ~= "C" and value ~= "POSIX" then
            candidate = value
            break
        end
    end
    if not candidate then
        local file = io.open(policy.systemFile, "r")
        if file then
            for line in file:lines() do
                candidate = line:match("^LANG=(.*)$")
                if candidate then break end
            end
            assert(file:close())
        end
    end
    local language = (candidate or ""):lower():match("^[^._@]+")
    local supported = false
    for _, value in ipairs(policy.languages) do
        if value == language then supported = true end
    end
    if not supported then language = policy.default end
    return setmetatable(
        { language = language, messages = File.properties(directory .. "/" .. language .. ".msg") },
        Catalog
    )
end

function Catalog:text(key, ...)
    return string.format(assert(self.messages[key], "missing_message:" .. key), ...)
end

return Catalog
