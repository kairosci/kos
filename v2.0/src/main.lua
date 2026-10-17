local root = assert(arg[1], "project_root_required")
package.path = root .. "/src/?.lua;" .. package.path
local application = require("component.runtime.application").new(root)
local arguments = {}
for index = 2, #arg do arguments[#arguments + 1] = arg[index] end
local ok, failure = pcall(application.run, application, arguments)
if not ok then
    application:report(failure)
    os.exit(1)
end
if application.layout.statusModes[arguments[1]] then
    assert(math.type(failure) == "integer" and failure >= 0 and failure <= 255, "invalid_runtime_status")
    os.exit(failure)
end
