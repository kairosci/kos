local root, name = assert(arg[1]), assert(arg[2])
package.path = root .. "/src/?.lua;" .. package.path
local File = require("core.file")
local Settings = require("component.application.settings")
local backend = {}
function backend:run(command, arguments)
    assert(command == "gsettings")
    local log = assert(io.open(assert(os.getenv("GUI_TEST_ARGS")), "a"))
    assert(log:write(table.concat(arguments, " "), "\n")); assert(log:close())
    return ""
end
Settings.new(root, backend, File.json(root .. "/data/component/application/policy.json")):apply(name)
