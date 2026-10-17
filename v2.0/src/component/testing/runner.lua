local Runner = {}
Runner.__index = Runner

function Runner.new(root, process, policy, output)
    return setmetatable({root=root, process=process, policy=policy, output=output or io.stdout}, Runner)
end

function Runner:execute(suite)
    local path = suite.path:sub(1, 1) == "/" and suite.path or self.root .. "/" .. suite.path
    local handle, failure, code = io.open(path, "rb")
    if not handle then assert(code == 2, failure); return nil, "missing" end
    assert(handle:close())
    local arguments = {path}
    if suite.language == "lua" then arguments[#arguments + 1] = self.root end
    for _, argument in ipairs(suite.arguments or {}) do arguments[#arguments + 1] = argument end
    return self.process:capture(assert(self.policy.commands[suite.language], "unsupported_test_language"), arguments, true)
end

function Runner.evaluate(output, status)
    local counts = {pass=0, fail=0, warn=0}
    local reported, reportedPassed, reportedFailed, reportedWarned
    for line in (output .. "\n"):gmatch("([^\n]*)\n") do
        local kind = line:match("^  (pass) ") or line:match("^  (fail) ") or line:match("^  (warn) ")
        if kind then counts[kind] = counts[kind] + 1 end
        local total, passed, failed, warned = line:match("^Summary: Tests Executed: (%d+) | Passed: (%d+) | Failed: (%d+) | Warnings: (%d+)$")
        if total then reported, reportedPassed, reportedFailed, reportedWarned = tonumber(total), tonumber(passed), tonumber(failed), tonumber(warned) end
    end
    local assertions = counts.pass + counts.fail + counts.warn
    local consistent = reported == assertions and reportedPassed == counts.pass and reportedFailed == counts.fail and reportedWarned == counts.warn
    return status == 0 and counts.fail == 0 and consistent, assertions, consistent
end

function Runner:run(suites)
    assert(#suites > 0, "empty_test_suite_selection")
    local total, passed, failed = 0, 0, 0
    for _, suite in ipairs(suites) do
        local output, status = self:execute(suite)
        local accepted, assertions, consistent = false, 0, false
        if output then
            self.output:write(output)
            accepted, assertions, consistent = Runner.evaluate(output, status)
            if not consistent then self.output:write("fail suite ", suite.path, " reported an incorrect test count\n") end
            if status ~= 0 then self.output:write("fail suite ", suite.path, "\n") end
        else self.output:write("fail suite ", suite.path, " is missing\n") end
        total = total + assertions
        if accepted then passed = passed + 1 else failed = failed + 1 end
    end
    self.output:write(("Tests Executed: %d | Suites: %d | Passed: %d | Failed: %d\n"):format(total, #suites, passed, failed))
    return failed == 0 and 0 or 1
end

return Runner
