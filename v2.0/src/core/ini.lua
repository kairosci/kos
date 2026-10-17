local Ini = {}

function Ini.merge(desired, current)
    local sections, order, section = {}, {}, ""
    for line in desired:gmatch("[^\r\n]+") do
        local heading = line:match("^%[([^%]]+)%]$")
        if heading then
            section = heading
            assert(not sections[section], "duplicate_ini_section")
            sections[section] = { keys = {}, values = {} }
            order[#order + 1] = section
        else
            local key = line:match("^([^#;=]+)=")
            assert(key and sections[section], "invalid_ini_policy")
            key = key:match("^%s*(.-)%s*$")
            local policy = sections[section]
            assert(not policy.values[key], "duplicate_ini_key")
            policy.keys[#policy.keys + 1] = key
            policy.values[key] = line
        end
    end
    local output, emitted = {}, {}
    local function emit(name)
        local policy = sections[name]
        if not policy or emitted[name] then return end
        for _, key in ipairs(policy.keys) do
            output[#output + 1] = policy.values[key]
        end
        emitted[name] = true
    end
    section = ""
    for line in (current .. "\n"):gmatch("([^\n]*)\n") do
        local heading = line:match("^%[([^%]]+)%]$")
        if heading then
            section = heading
            output[#output + 1] = line
            emit(section)
        else
            local key = line:match("^([^#;=]+)=")
            key = key and key:match("^%s*(.-)%s*$")
            if not (key and sections[section] and sections[section].values[key]) then output[#output + 1] = line end
        end
    end
    while output[#output] == "" do
        output[#output] = nil
    end
    for _, name in ipairs(order) do
        if not emitted[name] then
            output[#output + 1] = "[" .. name .. "]"
            emit(name)
        end
    end
    return table.concat(output, "\n") .. "\n"
end

return Ini
