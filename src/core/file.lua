local Json = require("core.json")
local File = {}

function File.read(path)
    local handle = assert(io.open(path, "rb"))
    local content = assert(handle:read("a"))
    assert(handle:close())
    return content
end

function File.json(path)
    return Json.decode(File.read(path))
end

function File.properties(path)
    local result = {}
    for line in (File.read(path) .. "\n"):gmatch("([^\n]*)\n") do
        if line ~= "" and not line:match("^%s*#") then
            local key, value = line:match("^([^=]+)=(.*)$")
            assert(key and result[key] == nil, "invalid_property")
            result[key] = value
        end
    end
    return result
end

function File.list(path)
    local result = {}
    for line in File.read(path):gmatch("[^\r\n]+") do
        if not line:match("^%s*#") then result[#result + 1] = line end
    end
    return result
end

return File
