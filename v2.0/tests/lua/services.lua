local File = require("core.file")
local Services = require("component.security.services")

return function(suite, root)
    local policy = File.json(root .. "/data/component/security/services.json")
    local process = {
        run = function(_, name)
            if name == "identity" then return "0\n" end
            if name == "directory" or name == "permissions" or name == "systemdDaemonReload" then return "" end
            error("unexpected_run_" .. name)
        end,
        status = function(_, name)
            if name == "isLink" or name == "pathExists" then return 1 end
            if name == "journaldRestart" or name == "systemdDisableUnit" or name == "systemdDaemonReload" then return 0 end
            error("unexpected_status_" .. name)
        end,
        capture = function(_, name, args)
            if name == "systemdUnitFiles" or name == "systemdUnitFilesPrivileged" then
                return args[1] == "cups.service" and "cups.service disabled\n" or "", 0
            end
            if name == "securityFilePrivileged" then return policy.files[args[1]], 0 end
            if name == "systemdUnitEnabledPrivileged" then return "disabled\n", 1 end
            error("unexpected_capture_" .. name)
        end,
    }
    suite:test("service policy contains resolver and journal configuration", function()
        assert(policy.files["/etc/systemd/resolved.conf.d/hardened.conf"]:find("LLMNR=no", 1, true))
        assert(policy.files["/etc/systemd/journald.conf.d/security.conf"]:find("SystemMaxUse=500M", 1, true))
    end)
    suite:test("service policy applies without errors", function()
        local publisher = { new = function()
            return { publish = function(_, path, content)
                assert(policy.files[path] == content)
            end }
        end }
        Services.new(process, policy, nil, publisher):apply()
    end)
    suite:test("service verification accepts compliant state", function() assert(Services.new(process, policy):verify()) end)
    suite:test("service verification rejects configuration drift", function()
        local altered = setmetatable({ capture = function(_, name, args)
            if name == "securityFilePrivileged" then return "drift", 0 end
            return process:capture(name, args)
        end }, { __index = process })
        assert(not Services.new(altered, policy):verify())
    end)
    suite:test("service verification rejects conflicting NetworkManager policy", function()
        local conflicting = setmetatable({ status = function(_, name, args)
            if name == "pathExists" and args[1] == "/etc/NetworkManager/conf.d/security.conf" then return 0 end
            return process:status(name, args)
        end }, { __index = process })
        assert(not Services.new(conflicting, policy):verify())
    end)
    suite:test("service verification fails when the NetworkManager path probe errors", function()
        local unknown = setmetatable({ status = function(_, name, args)
            if name == "pathExists" and args[1] == "/etc/NetworkManager/conf.d/security.conf" then return 2 end
            return process:status(name, args)
        end }, { __index = process })
        assert(not Services.new(unknown, policy):verify())
    end)
    suite:test("service policy rejects non-root application", function()
        local nonroot = setmetatable({ run = function(_, name)
            if name == "identity" then return "1000\n" end
            error("unexpected_run_" .. name)
        end }, { __index = process })
        suite:reject(function() Services.new(nonroot, policy):apply() end)
    end)
end
