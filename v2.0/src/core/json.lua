local Json = {null = {}}
local array = {}

function Json.array(values)
    return setmetatable(values, array)
end

function Json.isArray(value)
    return type(value) == "table" and getmetatable(value) == array
end

function Json.decode(source)
    assert(utf8.len(source), "json_invalid_utf8")
    local position = 1
    local parse
    local function space()
        local _, finish = source:find("^[ \r\n\t]*", position)
        position = finish + 1
    end
    local function string_value()
        assert(source:sub(position, position) == '"', "json_string")
        position = position + 1
        local result = {}
        while position <= #source do
            local char = source:sub(position, position)
            position = position + 1
            if char == '"' then return table.concat(result) end
            if char == "\\" then
                local escape = source:sub(position, position)
                position = position + 1
                local escapes = {['"']='"', ['\\']='\\', ['/']='/', b='\b', f='\f', n='\n', r='\r', t='\t'}
                if escape == "u" then
                    local hex = source:sub(position, position + 3)
                    assert(hex:match("^%x%x%x%x$"), "json_unicode")
                    position = position + 4
                    local code = tonumber(hex, 16)
                    if code >= 0xD800 and code <= 0xDBFF then
                        assert(source:sub(position, position + 1) == "\\u", "json_surrogate")
                        local low = source:sub(position + 2, position + 5)
                        assert(low:match("^%x%x%x%x$"), "json_surrogate")
                        low = tonumber(low, 16)
                        assert(low >= 0xDC00 and low <= 0xDFFF, "json_surrogate")
                        code = 0x10000 + (code - 0xD800) * 0x400 + low - 0xDC00
                        position = position + 6
                    else
                        assert(code < 0xD800 or code > 0xDFFF, "json_surrogate")
                    end
                    result[#result + 1] = utf8.char(code)
                else
                    result[#result + 1] = assert(escapes[escape], "json_escape")
                end
            else
                assert(char:byte() >= 32, "json_control")
                result[#result + 1] = char
            end
        end
        error("json_unterminated_string")
    end
    parse = function()
        space()
        local char = source:sub(position, position)
        if char == '"' then return string_value() end
        if char == "{" or char == "[" then
            local object = char == "{"
            local result = object and {} or Json.array({})
            local close = object and "}" or "]"
            position = position + 1
            space()
            if source:sub(position, position) == close then position = position + 1; return result end
            while true do
                space()
                local key = object and string_value() or #result + 1
                space()
                if object then
                    assert(result[key] == nil, "json_duplicate_key")
                    assert(source:sub(position, position) == ":", "json_colon")
                    position = position + 1
                end
                result[key] = parse()
                space()
                local separator = source:sub(position, position)
                position = position + 1
                if separator == close then return result end
                assert(separator == ",", "json_separator")
            end
        end
        for literal, value in pairs({["true"]=true, ["false"]=false, ["null"]=Json.null}) do
            if source:sub(position, position + #literal - 1) == literal then position = position + #literal; return value end
        end
        local token = source:match("^[-+%d.eE]+", position)
        assert(token, "json_value")
        local mantissa, exponent = token:match("^(.-)[eE]([+-]?%d+)$")
        mantissa = mantissa or token
        assert(not mantissa:find("[eE]"), "json_number")
        local integer, fraction = mantissa:match("^(%-?%d+)%.(%d+)$")
        integer = integer or mantissa
        assert(integer:match("^%-?%d+$") and not integer:match("^%-?0%d"), "json_number")
        assert(not mantissa:find("%.") or fraction, "json_number")
        local number = assert(tonumber(token), "json_number")
        assert(number ~= math.huge and number ~= -math.huge, "json_number")
        position = position + #token
        return number
    end
    local value = parse()
    space()
    assert(position > #source, "json_trailing_data")
    return value
end

function Json.encode(value)
    if value == Json.null then return "null" end
    local kind = type(value)
    if kind == "string" then
        return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
            local escapes = {['"']='\\"', ['\\']='\\\\', ['\n']='\\n', ['\r']='\\r', ['\t']='\\t'}
            return escapes[char] or string.format("\\u%04x", char:byte())
        end) .. '"'
    end
    if kind == "boolean" then return tostring(value) end
    if kind == "number" then assert(value == value and math.abs(value) ~= math.huge, "json_number"); return tostring(value) end
    assert(kind == "table", "json_type")
    local result = {}
    if Json.isArray(value) then
        for _, item in ipairs(value) do result[#result + 1] = Json.encode(item) end
        return "[" .. table.concat(result, ",") .. "]"
    end
    local keys = {}
    for key in pairs(value) do assert(type(key) == "string", "json_key"); keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do result[#result + 1] = Json.encode(key) .. ":" .. Json.encode(value[key]) end
    return "{" .. table.concat(result, ",") .. "}"
end

return Json
