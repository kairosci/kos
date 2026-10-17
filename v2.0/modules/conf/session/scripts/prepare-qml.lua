local qml = dofile(arg[0]:match("^(.*[/])") .. "qml.lua")
local input = assert(io.open(assert(arg[1]), "r"))
local source = input:read("*a")
input:close()
if arg[2] == "localize" then
  source = qml.localize(source)
  if arg[3] and arg[3] ~= "." then source = 'import "' .. arg[3] .. '"\n' .. source end
else
  source = qml.clean(source)
end
io.write(source)
