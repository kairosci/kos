local function quote(value)
    return '"'
        .. value:gsub('[%z\1-\31\\"]', function(char)
            if char == '"' then return '\\"' end
            if char == "\\" then return "\\\\" end
            return string.format("\\u%04x", char:byte())
        end)
        .. '"'
end
return function(values)
    local keys, result = {}, {}
    for key, value in pairs(values) do
        assert(type(key) == "string" and type(value) == "string")
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        result[#result + 1] = quote(key) .. ":" .. quote(values[key])
    end
    return "{" .. table.concat(result, ",") .. "}\n"
end
