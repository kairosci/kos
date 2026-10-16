local File = require("core.file")
local Json = require("core.json")
local Editor = {}
Editor.__index = Editor

function Editor.new(root, process, policy)
    return setmetatable({root=root, process=process, policy=policy}, Editor)
end

function Editor.plan(memory, processors, policy)
    local total = tonumber(memory:match("MemTotal:%s*(%d+)%s+kB"))
    assert(total and total > 0 and processors and processors >= 1 and processors % 1 == 0, "invalid_hardware_observation")
    assert(policy.memoryFraction > 0 and policy.memoryFraction < 1 and policy.workerMemoryKiB > 0 and policy.maximumWorkers >= 1 and policy.reservedProcessors >= 0, "invalid_performance_policy")
    for _, name in ipairs({"workerMemoryKiB", "maximumWorkers", "primingWorkers", "syntaxCacheCapacity"}) do
        assert(type(policy[name]) == "number" and policy[name] >= 1 and policy[name] % 1 == 0, "invalid_performance_policy_" .. name)
    end
    local memory_workers = math.max(1, math.floor(total * policy.memoryFraction / policy.workerMemoryKiB))
    local cpu_workers = math.max(1, processors - policy.reservedProcessors)
    local workers = math.min(memory_workers, cpu_workers, policy.maximumWorkers)
    return {workers=workers, priming=math.min(workers, policy.primingWorkers), cache=policy.syntaxCacheCapacity}
end

function Editor.merge(target, source)
    assert(type(target) == "table" and target ~= Json.null and type(source) == "table" and source ~= Json.null, "invalid_settings_object")
    for key, value in pairs(source) do
        if type(value) == "table" and value ~= Json.null and not getmetatable(value) and type(target[key]) == "table" and target[key] ~= Json.null and not getmetatable(target[key]) then
            Editor.merge(target[key], value)
        else target[key] = value end
    end
    return target
end

function Editor.assign(target, path, value)
    for index, key in ipairs(path) do
        if index == #path then target[key] = value
        else
            if target[key] == nil then target[key] = {} end
            assert(type(target[key]) == "table" and target[key] ~= Json.null and not getmetatable(target[key]), "invalid_settings_path")
            target = target[key]
        end
    end
    return target
end

function Editor:render(existing)
    local content = File.read(assert(existing, "settings_path_required"))
    local settings = content == "" and {} or Json.decode(content)
    assert(type(settings) == "table" and settings ~= Json.null and not getmetatable(settings), "invalid_settings_object")
    for _, path in ipairs(self.policy.defaults) do self.merge(settings, File.json(self.root .. "/" .. path)) end
    local plan = self.plan(File.read(self.policy.memoryInfo), tonumber(self.process:run("processorCount")), self.policy)
    local prefix = self.policy.optionsPath
    for _, definition in ipairs(self.policy.calculated) do
        local path = {}
        for _, key in ipairs(prefix) do path[#path + 1] = key end
        for _, key in ipairs(definition.path) do path[#path + 1] = key end
        local value = assert(plan[definition.value], "unknown_performance_value")
        self.assign(settings, path, definition.string and tostring(value) or value)
    end
    return settings
end

return Editor
