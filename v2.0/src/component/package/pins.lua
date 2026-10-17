local Pins = {}
Pins.__index = Pins

function Pins.new(process, policy)
    return setmetatable({ process = assert(process), policy = assert(policy) }, Pins)
end

local function matches(package, pattern)
    local expression = "^" .. pattern:gsub("([%^%$%(%)%%%.%[%]%+%-%?])", "%%%1"):gsub("%*", ".*") .. "$"
    return package:match(expression) ~= nil
end

function Pins:retained_updateable()
    local output = self.process:run("pacmanIgnorePackages")
    for pattern in output:gmatch("%S+") do
        for _, package in ipairs(self.policy.updateableRetained) do
            if matches(package, pattern) then return false end
        end
    end
    return true
end

return Pins
