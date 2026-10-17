local root = assert(arg[1], "project_root_required")
package.path = root .. "/src/?.lua;" .. package.path
local File = require("core.file")
local Runner = require("component.testing.runner")
local Process = require("core.process")
local ok, status = pcall(function()
    local policy = File.json(root .. "/data/component/testing/policy.json")
    local suites
    if arg[2] == "--group" then
        assert(arg[3] and not arg[4], "invalid_test_group_arguments")
        suites = assert(policy.groups[arg[3]], "unknown_test_group")
    else
        assert(arg[2] == "--suite" and arg[3], "test_selection_required")
        suites = {}
        for index = 3, #arg do
            local path = arg[index]
            suites[#suites + 1] = { path = path, language = path:match("%.lua$") and "lua" or "shell" }
        end
    end
    return Runner.new(root, Process.new(File.json(root .. "/data/core/commands.json")), policy):run(suites)
end)
if not ok then
    io.stderr:write(tostring(status), "\n")
    os.exit(1)
end
os.exit(status)
