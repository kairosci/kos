local File = require("core.file")
local Audit = require("component.security.audit")

return function(suite, root)
    local policy = File.json(root .. "/data/component/security/audit.json")
    local function fixture(options)
        options = options or {}
        local calls = {}
        local process = {
            run = function(_, name, args)
                calls[#calls + 1] = { name = name, args = args }
                if name == "identity" then return "0\n" end
                if name == "fileMode" then return "81ed\n" end
                return ""
            end,
            status = function(_, name, args)
                if name == "systemdUnitEnabled" then return args[1] == "cronie.service" and options.cronEnabled and 0 or 1 end
                if name == "systemdUnitActive" then return args[1] == "cronie.service" and options.cronActive and 0 or 1 end
                if name == "systemdTimerEnabled" then return options.timerEnabled and 0 or 1 end
                if name == "systemdTimerActive" then return options.timerActive and 0 or 1 end
                return 0
            end,
            capture = function(_, name, args)
                if name == "securityFilePrivileged" then return policy.files[args[1]], 0 end
                if name == "weeklyLynis" or name == "weeklyRkhunter" or name == "weeklyClamav" or name == "weeklyArchAudit" then
                    return options.output or "ok\n", options.commandStatus or 0
                end
                if name == "weeklyArchAuditReview" then return options.findings or "", options.reviewStatus or 0 end
                error("unexpected_capture_" .. name)
            end,
        }
        return process, calls
    end
    suite:test("audit policy owns timer service logrotate and cron starter", function()
        assert(policy.files["/etc/systemd/system/os-security-audit.timer"]:find("OnCalendar=weekly", 1, true))
        assert(policy.files["/etc/cron.weekly/security-audit.sh"]:find("run-security-audit", 1, true))
        assert(policy.files["/etc/logrotate.d/os-security-audit"]:find("rotate 12", 1, true))
    end)
    suite:test("audit scheduler publishes files and selects exactly one scheduler", function()
        local process, calls = fixture({ cronEnabled = true })
        local publisher = { new = function() return { publish = function() end } end }
        Audit.new(process, policy, publisher):apply()
        local cron, timer = false, false
        for _, call in ipairs(calls) do
            if call.name == "systemdUnitEnableNow" then
                cron = cron or call.args[1] == "cronie.service"
                timer = timer or call.args[1] == policy.timer
            end
        end
        assert(cron and not timer)
    end)
    suite:test("audit verification accepts either scheduler exclusively", function()
        local process = fixture({ cronEnabled = true, cronActive = true })
        process.status = function(_, name, args)
            if name == "systemdUnitEnabled" then return args[1] == "cronie.service" and 0 or 1 end
            if name == "systemdUnitActive" then return args[1] == "cronie.service" and 0 or 1 end
            if name == "systemdTimerEnabled" or name == "systemdTimerActive" then return 1 end
            return 0
        end
        assert(Audit.new(process, policy):verify())
        process.status = function(_, name)
            if name == "systemdUnitEnabled" or name == "systemdUnitActive" or name == "systemdTimerEnabled" or name == "systemdTimerActive" then return 0 end
            return 0
        end
        assert(not Audit.new(process, policy):verify())
    end)
    suite:test("audit report findings fail the run", function()
        local process = fixture({ findings = "pkg 1 CVE-2026-1234\n" })
        local log = os.tmpname()
        local altered = File.json(root .. "/data/component/security/audit.json")
        altered.logs.lynis = log
        altered.logs.rkhunter = log
        altered.logs["arch-audit"] = log
        suite:reject(function() Audit.new(process, altered):run() end)
        assert(os.remove(log))
    end)
end
