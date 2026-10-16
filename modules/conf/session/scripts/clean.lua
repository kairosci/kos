local input = assert(io.open(assert(arg[1]), "r"))
local source = input:read("*a")
input:close()

local function strip(text, literals, keep_comments)
  local result, i = {}, 1
  local function literal(value)
    if not literals then return value end
    literals[#literals + 1] = value
    return "\1" .. #literals .. "\2"
  end
  while i <= #text do
    local c = text:sub(i, i)
    local comment = text:sub(i, i + 1) == "--"
    local start = comment and i + 2 or i
    local equals = text:sub(start):match("^%[(=*)%[")
    if equals then
      local ending = "]" .. equals .. "]"
      local first, last = text:find(ending, start + #equals + 2, true)
      assert(first, "Unterminated Lua block")
      if comment then
        result[#result + 1] = keep_comments and literal(text:sub(i, last)) or (" " .. ("\n"):rep(select(2, text:sub(i, last):gsub("\n", ""))))
      else
        result[#result + 1] = literal(text:sub(i, last))
      end
      i = last + 1
    elseif comment then
      local ending = text:find("\n", i, true) or (#text + 1)
      if keep_comments then result[#result + 1] = text:sub(i, ending - 1) end
      i = ending
    elseif c == '"' or c == "'" then
      local ending = i + 1
      while ending <= #text do
        if text:sub(ending, ending) == "\\" then
          ending = ending + 2
        elseif text:sub(ending, ending) == c then
          break
        else
          ending = ending + 1
        end
      end
      assert(ending <= #text, "Unterminated Lua string")
      result[#result + 1] = literal(text:sub(i, ending))
      i = ending + 1
    else
      result[#result + 1] = c
      i = i + 1
    end
  end
  return table.concat(result)
end

local function normalize(text)
  text = strip(text)
  text = text:gsub('dofile%(%(os.getenv%("OMARCHY_PATH"%) or "/usr/share/omarchy"%) %.%. "/default/hypr/bootstrap.lua"%)',
    'local desktop = dofile((os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")) .. "/os/hypr/runtime.lua")')
  text = text:gsub('require%("default.hypr.omarchy"%)', 'desktop.defaults()')
  text = text:gsub('require%("default.hypr.toggles"%)', 'desktop.toggles()')
  text = text:gsub("omarchy_gdk_scale", "gdk_scale"):gsub("omarchy_monitor_scale", "monitor_scale")
  text = text:gsub("omarchy%-cmd%-terminal%-cwd", "os cmd terminal cwd")
  text = text:gsub("/omarchy/herdr%-keybindings%-menu", "/os/herdr-keybindings-menu")
  local literals = {}
  text = strip(text, literals):gsub("[ \t]+\n", "\n"):gsub("\n\n\n+", "\n\n")
  text = text:match("^%s*(.-)%s*$")
  return (text:gsub("\1(%d+)\2", function(index) return literals[tonumber(index)] end))
end

local previous, blocks, order, counts = {}, {}, {}, {}
if arg[2] then
  local state = io.open(arg[2], "r")
  if state then
    local data = state:read("*a")
    state:close()
    for key, value in data:gmatch("([^%z]+)%z([^%z]*)%z") do previous[key] = value end
  end
end
local literals = {}
source = strip(source, literals, true)
local function restore(text)
  return (text:gsub("\1(%d+)\2", function(index) return literals[tonumber(index)] end))
end
source = source:gsub("%-%- ([^\n]-) %(managed%)\n(.-)%-%- end %1 %(managed%)", function(key, body)
  if not blocks[key] then order[#order + 1] = key end
  blocks[key] = normalize(restore(body))
  counts[key] = (counts[key] or 0) + 1
  return "\3" .. key .. "\4"
end)
source = normalize(restore(source))
for _, key in ipairs(order) do
  local body = blocks[key]
  if previous[key] then
    assert(type(previous[key]) == "string")
    source = source:gsub(previous[key]:gsub("(%W)", "%%%1"), "")
  end
  if body ~= "" then
    local pattern = body:gsub("(%W)", "%%%1")
    source = source:gsub(pattern, "")
  end
  source = source:gsub("\3" .. key:gsub("(%W)", "%%%1") .. "\4", function()
    counts[key] = counts[key] - 1
    return counts[key] == 0 and body or ""
  end)
end
source = normalize(source) .. "\n"
assert(not source:lower():find("omarchy", 1, true), "Unmapped runtime reference in " .. arg[1])
assert(load(source, "@" .. arg[1]))
if arg[3] and arg[3] ~= "" then
  for key, body in pairs(blocks) do previous[key] = body end
  local state = assert(io.open(arg[3], "w"))
  local encode = dofile(arg[0]:match("^(.*[/])") .. "json.lua")
  state:write(encode(previous))
  state:close()
end
io.write(source)
