local Process = {}
Process.__index = Process

function Process.new(commands)
    return setmetatable({commands = assert(commands)}, Process)
end

function Process.quote(value)
    assert(type(value) == "string" and not value:find("%z"), "invalid_argument")
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

function Process:command(name, arguments)
    local command = assert(self.commands[name], "unknown_command")
    local words = {}
    for _, value in ipairs(command) do words[#words + 1] = Process.quote(value) end
    for _, value in ipairs(arguments or {}) do words[#words + 1] = Process.quote(value) end
    return table.concat(words, " ")
end

function Process:status(name, arguments)
    local success, reason, status = os.execute(self:command(name, arguments))
    if success then return 0 end
    assert(reason == "exit" or reason == "signal", "invalid_process_status")
    return reason == "signal" and 128 + status or status
end

function Process:capture(name, arguments)
    local pipe = assert(io.popen(self:command(name, arguments), "r"))
    local output, read_error = pipe:read("a")
    local success, reason, status = pipe:close()
    assert(output, read_error)
    if success then return output, 0 end
    assert(reason == "exit" or reason == "signal", "invalid_process_status")
    return output, reason == "signal" and 128 + status or status
end

function Process:run(name, arguments)
    local output, status = self:capture(name, arguments)
    assert(status == 0, name .. ":exit:" .. tostring(status))
    return output
end

return Process
