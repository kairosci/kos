local File = require("core.file")
local Runner = require("component.testing.runner")
return function(suite, root, process)
    local cases = {
        {
            name = "consistent passing assertions",
            output = "  pass example\nSummary: Tests Executed: 1 | Passed: 1 | Failed: 0 | Warnings: 0\n",
            status = 0,
            accepted = true,
        },
        {
            name = "failed assertions despite zero exit status",
            output = "  fail example\nSummary: Tests Executed: 1 | Passed: 0 | Failed: 1 | Warnings: 0\n",
            status = 0,
            accepted = false,
        },
        { name = "missing assertion summary", output = "", status = 0, accepted = false },
        {
            name = "inflated assertion counts",
            output = "  pass example\nSummary: Tests Executed: 2 | Passed: 2 | Failed: 0 | Warnings: 0\n",
            status = 0,
            accepted = false,
        },
        {
            name = "nonzero exit after successful assertions",
            output = "  pass example\nSummary: Tests Executed: 1 | Passed: 1 | Failed: 0 | Warnings: 0\n",
            status = 7,
            accepted = false,
        },
        {
            name = "warning assertions",
            output = "  warn example\nSummary: Tests Executed: 1 | Passed: 0 | Failed: 0 | Warnings: 1\n",
            status = 0,
            accepted = true,
        },
    }
    for _, case in ipairs(cases) do
        suite:test("suite runner validates " .. case.name, function()
            assert(Runner.evaluate(case.output, case.status) == case.accepted)
        end)
    end
    suite:test("missing test files fail without invoking an interpreter", function()
        local output = {
            text = "",
            write = function(self, ...)
                for _, value in ipairs({ ... }) do
                    self.text = self.text .. value
                end
            end,
        }
        local backend = {
            capture = function()
                error("unexpected_process")
            end,
        }
        local runner = Runner.new(root, backend, File.json(root .. "/data/component/testing/policy.json"), output)
        assert(runner:run({ { path = "tests/does-not-exist.lua", language = "lua" } }) == 1)
        assert(output.text:find("Failed: 1", 1, true))
    end)
    suite:test("a native Lua suite receives literal arguments and captured stderr", function()
        local directory = process:run("temporary", { "-d" }):gsub("\n$", "")
        local path = directory .. "/suite with spaces.lua"
        local handle = assert(io.open(path, "wb"))
        assert(handle:write([[assert(arg[2] == "literal $(never execute)" )
io.stderr:write("diagnostic\n")
print("  pass native fixture")
print("Summary: Tests Executed: 1 | Passed: 1 | Failed: 0 | Warnings: 0")
]]))
        assert(handle:close())
        local output = {
            text = "",
            write = function(self, ...)
                for _, value in ipairs({ ... }) do
                    self.text = self.text .. value
                end
            end,
        }
        local runner = Runner.new(root, process, File.json(root .. "/data/component/testing/policy.json"), output)
        local status = runner:run({ { path = path, language = "lua", arguments = { "literal $(never execute)" } } })
        process:run("removeDirectory", { directory })
        assert(
            status == 0
                and output.text:find("diagnostic", 1, true)
                and output.text:find("Tests Executed: 1 | Suites: 1", 1, true)
        )
    end)
end
