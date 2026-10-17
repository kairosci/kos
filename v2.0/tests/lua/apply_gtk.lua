local root = assert(arg[1])
package.path = root .. "/src/?.lua;" .. package.path
local File = require("core.file")
local Process = require("core.process")
local Paths = require("core.paths")
local Publisher = require("core.publisher")
local process = Process.new(File.json(root .. "/data/core/commands.json"))
local backend = {}
function backend:run(command, arguments)
    if command == "gsettings" then
        local log = assert(io.open(assert(os.getenv("GUI_TEST_ARGS")), "a"))
        assert(log:write("set ", table.concat(arguments, " "), "\n"))
        assert(log:close())
        return ""
    end
    return process:run(command, arguments)
end
function backend:status(command, arguments)
    return process:status(command, arguments)
end
function backend:capture(command, arguments, merge)
    return process:capture(command, arguments, merge)
end
local registry = File.json(root .. "/data/component/application/policy.json")
local paths = Paths.new(File.json(root .. "/data/core/paths.json"))
local publisher = Publisher.new(backend)
assert(
    require("component.application.gtk").new(root, paths, publisher, backend, registry):apply("gtk")
        == registry.gtk.display
)
