local function read(path)
  local file = assert(io.open(path, "r"))
  local value = file:read("*a")
  file:close()
  return value
end
local text = read(assert(arg[1]))
local mode = assert(arg[3])
text = 'import "../' .. assert(arg[4]) .. '"\n' .. text
if mode == "media" then
  text = text:gsub("Ui.BarWidget {", "Ui.Panel {", 1)
  text = text:gsub("function close%(%) { panelOpen = false }", "function open() { root.controller.show(); panelOpen = true }\n  function close() { root.controller.hide(); panelOpen = false }", 1)
end
text = text:gsub("PopupCard%s*{", "ControlPopup {")
text = text:gsub("KeyboardPanel%s*{", "ControlPopup {")
local ending = assert(text:find("}%s*$"))
text = text:sub(1, ending - 1) .. read(assert(arg[2])) .. "\n" .. text:sub(ending)
if not text:find("import Quickshell.Io", 1, true) then text = "import Quickshell.Io\n" .. text end
io.write(text)
