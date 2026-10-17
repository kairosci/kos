local M = {}
function M.tokens(source)
    local out, i, previous = {}, 1, nil
    local function emit(kind, last)
        local value = source:sub(i, last)
        out[#out + 1] = { kind = kind, value = value, first = i, last = last }
        if kind ~= "space" and kind ~= "comment" then previous = value end
        i = last + 1
    end
    while i <= #source do
        local c, pair = source:sub(i, i), source:sub(i, i + 1)
        if c:match("%s") then
            local last = source:find("[^%s]", i) or (#source + 1)
            emit("space", last - 1)
        elseif pair == "//" then
            emit("comment", (source:find("\n", i, true) or (#source + 1)) - 1)
        elseif pair == "/*" then
            local last = assert(source:find("*/", i + 2, true), "Unterminated comment")
            emit("comment", last + 1)
        elseif c == '"' or c == "'" or c == "`" then
            local last = i + 1
            while last <= #source do
                if source:sub(last, last) == "\\" then
                    last = last + 2
                elseif source:sub(last, last) == c then
                    break
                else
                    last = last + 1
                end
            end
            assert(last <= #source, "Unterminated string")
            emit("string", last)
        elseif
            c == "/"
            and (not previous or previous:match("^[=(:,%[!&|?{;]$") or previous == "return" or previous == "=>")
        then
            local last, bracket = i + 1, false
            while last <= #source do
                local next = source:sub(last, last)
                if next == "\\" then
                    last = last + 2
                elseif next == "[" then
                    bracket = true
                    last = last + 1
                elseif next == "]" then
                    bracket = false
                    last = last + 1
                elseif next == "/" and not bracket then
                    break
                else
                    last = last + 1
                end
            end
            assert(last <= #source, "Unterminated regular expression")
            while source:sub(last + 1, last + 1):match("[a-z]") do
                last = last + 1
            end
            emit("regex", last)
        elseif c:match("[%a_$]") then
            local last = i
            while source:sub(last + 1, last + 1):match("[%w_$]") do
                last = last + 1
            end
            emit("identifier", last)
        else
            emit("symbol", i)
        end
    end
    return out
end
function M.clean(source)
    local out = {}
    for _, token in ipairs(M.tokens(source)) do
        out[#out + 1] = token.kind == "comment" and (" " .. token.value:gsub("[^\n]", "")) or token.value
    end
    return table.concat(out)
end
function M.localize(source)
    source = M.clean(source)
    local tokens, edits = M.tokens(source), {}
    local display = { text = true, tooltipText = true, placeholderText = true }
    local function significant(index, direction)
        repeat
            index = index + direction
        until not tokens[index] or tokens[index].kind ~= "space"
        return index
    end
    for index, token in ipairs(tokens) do
        if token.value == ":" then
            local name_index = significant(index, -1)
            local name = tokens[name_index]
            local before_name = tokens[significant(name_index, -1)]
            if name and display[name.value] and (not before_name or before_name.value ~= ".") then
                local first = significant(index, 1)
                local last, depth, block = first - 1, 0, tokens[first] and tokens[first].value == "{"
                for cursor = first, #tokens do
                    local current = tokens[cursor]
                    local value = current.value
                    if depth == 0 and (value == ";" or value == "}" or value == ",") then break end
                    if depth == 0 and current.kind == "space" and value:find("\n", 1, true) then
                        local before, after = tokens[significant(cursor, -1)], tokens[significant(cursor, 1)]
                        local operators = {
                            ["?"] = true,
                            [":"] = true,
                            ["+"] = true,
                            ["-"] = true,
                            ["|"] = true,
                            ["&"] = true,
                            ["."] = true,
                        }
                        if not (before and operators[before.value]) and not (after and operators[after.value]) then
                            break
                        end
                    end
                    if current.kind == "symbol" then
                        if value == "(" or value == "[" or value == "{" then
                            depth = depth + 1
                        elseif value == ")" or value == "]" or value == "}" then
                            depth = depth - 1
                        end
                    end
                    last = cursor
                    if block and depth == 0 then break end
                end
                if last >= first then
                    local expr = source:sub(tokens[first].first, tokens[last].last)
                    local prefix = block and "SessionI18n.text((function() " or "SessionI18n.text("
                    local suffix = block and ")())" or ")"
                    local external = expr:find("SessionI18n.text", 1, true)
                        or expr:match("^row%.label$")
                        or expr:match("^root%.title")
                        or expr:match("^root%.artist$")
                        or expr:match("^root%.album$")
                        or expr:match("^queueRow%.")
                        or expr:match("^sourceRow%.")
                    if not external then
                        edits[#edits + 1] =
                            { first = tokens[first].first, last = tokens[last].last, value = prefix .. expr .. suffix }
                    end
                end
            end
        end
    end
    for index = #edits, 1, -1 do
        local edit = edits[index]
        source = source:sub(1, edit.first - 1) .. edit.value .. source:sub(edit.last + 1)
    end
    source = source
        :gsub("Qt%.formatDateTime%(", "SessionI18n.formatDateTime(")
        :gsub("Qt%.formatDate%(", "SessionI18n.formatDate(")
    source =
        source:gsub('Qt%.locale%("en_US"%)', "SessionI18n.locale"):gsub("Qt%.locale%('en_US'%)", "SessionI18n.locale")
    return source
end
return M
