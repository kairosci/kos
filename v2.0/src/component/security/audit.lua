local Publisher = require("core.publisher")

local Audit = {}
Audit.__index = Audit

function Audit.new(process, policy, publisher)
    return setmetatable({ process = assert(process), policy = assert(policy), publisher = publisher or Publisher }, Audit)
end

local function append(path, content)
    local file, failure = io.open(path, "ab")
    assert(file, failure)
    local written, writeFailure = file:write(content)
    local closed, closeFailure = file:close()
    assert(written and closed, writeFailure or closeFailure)
end

function Audit:apply()
    local process = self.process
    assert(process:run("identity"):match("^0%s*$"), "root_required")
    for path, content in pairs(self.policy.files) do
        local mode = path:match("/cron%.weekly/") and "755" or "644"
        self.publisher.new(process):publish(path, content, mode)
    end
    process:run("systemdDaemonReload")
    local cronEnabled = process:status("systemdUnitEnabled", { self.policy.cron }) == 0
    local cronActive = process:status("systemdUnitActive", { self.policy.cron }) == 0
    if cronEnabled or cronActive then
        process:run("systemdUnitEnableNow", { self.policy.cron })
        process:run("systemdUnitDisableNow", { self.policy.timer })
    else
        process:run("systemdUnitEnableNow", { self.policy.timer })
    end
end

function Audit:run()
    assert(self.process:run("identity"):match("^0%s*$"), "root_required")
    local failures = {}
    local function check(command, log, arguments)
        local output, status = self.process:capture(command, arguments, true)
        if log then append(log, output) end
        if status ~= 0 then failures[#failures + 1] = command end
        return output, status
    end
    check("weeklyLynis", self.policy.logs.lynis)
    check("weeklyRkhunter", self.policy.logs.rkhunter)
    local clamArguments = {}
    for _, path in ipairs(self.policy.paths) do clamArguments[#clamArguments + 1] = path end
    check("weeklyClamav", nil, clamArguments)
    check("weeklyArchAudit", self.policy.logs["arch-audit"])
    local findings, status = self.process:capture("weeklyArchAuditReview", nil, true)
    if status ~= 0 then
        append(self.policy.logs["arch-audit"], findings)
        failures[#failures + 1] = "arch-audit-unavailable"
    elseif findings:match("%S") then
        append(self.policy.logs["arch-audit"], findings)
        failures[#failures + 1] = "arch-audit-review"
    end
    assert(#failures == 0, "security_audit_failed:" .. table.concat(failures, " "))
end

function Audit:verify()
    for path, expected in pairs(self.policy.files) do
        local content, status = self.process:capture("securityFilePrivileged", { path })
        if status ~= 0 or content ~= expected then return false end
    end
    local mode = tonumber(self.process:run("fileMode", { "/etc/cron.weekly/security-audit.sh" }), 16)
    if not mode or mode & 73 ~= 73 then return false end
    local timerEnabled = self.process:status("systemdTimerEnabled", { self.policy.timer }) == 0
    local timerActive = self.process:status("systemdTimerActive", { self.policy.timer }) == 0
    local cronEnabled = self.process:status("systemdUnitEnabled", { self.policy.cron }) == 0
    local cronActive = self.process:status("systemdUnitActive", { self.policy.cron }) == 0
    return (timerEnabled and timerActive and not cronEnabled and not cronActive)
        or (cronEnabled and cronActive and not timerEnabled and not timerActive)
end

return Audit
