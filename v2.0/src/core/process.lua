local Process = {}
Process.__index = Process

function Process.new(commands)
    return setmetatable({commands = assert(commands)}, Process)
end

function Process.quote(value)
    assert(type(value) == "string" and not value:find("%z"), "invalid_argument")
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

function Process:run(name, arguments)
    local command = assert(self.commands[name], "unknown_command")
    local words = {}
    for _, value in ipairs(command) do words[#words + 1] = Process.quote(value) end
    for _, value in ipairs(arguments or {}) do words[#words + 1] = Process.quote(value) end
    local pipe = assert(io.popen(table.concat(words, " "), "r"))
    local output, read_error = pipe:read("a")
    local success, reason, status = pipe:close()
    assert(output, read_error)
    assert(success, name .. ":" .. tostring(reason) .. ":" .. tostring(status))
    return output
end

return Process
