local File = require("core.file")
local Blocks = require("core.blocks")
local Editor = require("component.performance.editor")
local Environment = {}
Environment.__index = Environment

function Environment.new(process, paths, publisher, policy)
    return setmetatable({process=process, paths=paths, publisher=publisher, policy=policy}, Environment)
end

function Environment:apply(deferred)
    local policy = self.policy
    local home = self.paths:resolve("home", ""):gsub("/$", "")
    self.paths:protectHome(self.process, home)
    local plan = Editor.plan(File.read(policy.memoryInfo), tonumber(self.process:run("processorCount")), policy)
    local entries, exports = {}, {}
    for name, field in pairs(policy.environment.values) do
        assert(name:match("^[A-Z_][A-Z_0-9]*$"), "invalid_environment_key")
        local value = assert(plan[field], "unknown_environment_value")
        assert(type(value) == "number" and value >= 1 and value % 1 == 0, "invalid_environment_value")
        entries[#entries + 1] = name .. "=" .. tostring(value)
        exports[#exports + 1] = policy.environment.exportPrefix .. name .. "=" .. tostring(value)
    end
    assert(#entries > 0, "empty_build_environment")
    table.sort(entries); table.sort(exports)
    local shell = self.paths:resolve(policy.environment.shellRoot, policy.environment.shellFile)
    local handle, failure, code = io.open(shell, "rb")
    local content, mode
    if handle then
        content = assert(handle:read("a")); assert(handle:close())
        content = Blocks.merge(content, policy.environment.first, policy.environment.last, table.concat(exports, "\n"))
        local metadata = assert(tonumber(self.process:run("fileMode", {shell}), 16))
        assert(metadata & 0xF000 == 0x8000, "nonregular_shell_configuration")
        mode = ("%o"):format(metadata & 0xFFF)
    else assert(code == 2, failure) end
    self.publisher:publish(self.paths:resolve(policy.environment.root, policy.environment.file), table.concat(entries, "\n") .. "\n", policy.environment.mode)
    if content then self.publisher:publish(shell, content, mode) end
    if not deferred then self.process:run("userEnvironment", entries) end
end

return Environment
