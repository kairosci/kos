local Os_modules_conf_session_scripts_legacy_state_lua = {}
function Os_modules_conf_session_scripts_legacy_state_lua.run()
local file = assert(io.open(assert(arg[1]), "r"))
local text = file:read("*a")
file:close()
local values = assert(load(text, "@legacy-managed-state", "t", {}))()
assert(type(values) == "table")
local encode = dofile(arg[0]:match("^(.*[/])") .. "json.lua")
io.write(encode(values))

end
return Os_modules_conf_session_scripts_legacy_state_lua.run()
