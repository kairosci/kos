local file = assert(io.open(assert(arg[1]), "r"))
local text = file:read("*a")
file:close()
local result, i = {}, 1
while i <= #text do
    local char = text:sub(i, i)
    if char == '"' then
        local ending = i + 1
        while ending <= #text do
            local c = text:sub(ending, ending)
            if c == "\\" then
                ending = ending + 2
            elseif c == '"' then
                break
            else
                ending = ending + 1
            end
        end
        assert(ending <= #text)
        result[#result + 1] = text:sub(i, ending)
        i = ending + 1
    elseif text:sub(i, i + 1) == "//" then
        i = text:find("\n", i, true) or (#text + 1)
    elseif text:sub(i, i + 1) == "/*" then
        local ending = assert(text:find("*/", i + 2, true))
        result[#result + 1] = " "
        i = ending + 2
    else
        result[#result + 1] = char
        i = i + 1
    end
end
text = table.concat(result)
result, i = {}, 1
while i <= #text do
    local char = text:sub(i, i)
    if char == '"' then
        local ending = i + 1
        while ending <= #text do
            if text:sub(ending, ending) == "\\" then
                ending = ending + 2
            elseif text:sub(ending, ending) == '"' then
                break
            else
                ending = ending + 1
            end
        end
        result[#result + 1] = text:sub(i, ending)
        i = ending + 1
    else
        local nextchar = text:sub(i + 1):match("^%s*(.)")
        if char ~= "," or (nextchar ~= "}" and nextchar ~= "]") then result[#result + 1] = char end
        i = i + 1
    end
end
io.write(table.concat(result))
