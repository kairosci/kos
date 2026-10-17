local File = require("core.file")
local Stack = require("component.security.stack")

return function(suite, root)
    local policy = File.json(root .. "/data/component/security/stack.json")
    local usbRules = "allow id 1234:5678\n"
    local function fixture(options)
        options = options or {}
        local calls = {}
        local process = {
            run = function(_, name, args)
                calls[#calls + 1] = { name = name, args = args }
                if name == "identity" then return "0\n" end
                if name == "usbguardGenerate" then return usbRules end
                if name == "fileMode" then return args[1] == policy.usbguardRules and "8180\n" or "81a4\n" end
                return ""
            end,
            status = function(_, name, args)
                calls[#calls + 1] = { name = name, args = args }
                if name == "pacmanInstalled" then return options.missingPackages and 1 or 0 end
                if name == "pacmanInfo" or name == "pacmanInstall" or name == "freshclamUpdate" then return 0 end
                if name == "pacmanInfo" or name == "pacmanInstall" then return 0 end
                if name == "systemdUnitActive" then return 0 end
                if name == "isExecutable" then return 0 end
                if name == "freshclamRunning" then return 1 end
                if name == "systemdUnitEnabled" or name == "unitEnable" or name == "unitStart"
                    or name == "systemdUnitFiles" or name == "auditRulesLoad" or name == "apparmorEnforce" or name == "grubMenuUpdate" then return 0 end
                error("unexpected_status_" .. name)
            end,
            capture = function(_, name, args)
                if name == "pacmanQuery" then return "error: package '" .. args[1] .. "' was not found\n", options.queryFailure and 2 or 1 end
                if name == "securityFilePrivileged" then
                    local content = args[1] == policy.usbguardRules and (options.usbRules or usbRules) or policy.files[args[1]]
                    for _, group in pairs(policy.packageFiles) do content = content or group[args[1]] end
                    return content or "", 0
                end
                error("unexpected_capture_" .. name)
            end,
        }
        local publisher = { new = function()
            return {
                inspect = function(_, path)
                    if path == policy.usbguardRules then return options.usbExisting end
                    return nil
                end,
                publish = function(_, path, content, mode)
                    calls[#calls + 1] = { name = "publish", args = { path, content, mode } }
                end,
            }
        end }
        return process, calls, publisher
    end
    suite:test("security stack policy includes audit, Fail2ban and AppArmor files", function()
        assert(policy.files[policy.auditRules]:find("privilege_escalation", 1, true))
        assert(policy.packageFiles.fail2ban["/etc/fail2ban/jail.local"]:find("maxretry = 3", 1, true))
        assert(#policy.profiles == 4)
    end)
    suite:test("security stack preserves established USBGuard rules", function()
        local process, calls, publisher = fixture({ usbExisting = usbRules })
        Stack.new(process, policy, nil, publisher):apply()
        for _, call in ipairs(calls) do
            assert(not (call.name == "publish" and call.args[1] == policy.usbguardRules))
        end
    end)
    suite:test("security stack creates initial USBGuard rules when absent", function()
        local process, calls, publisher = fixture()
        Stack.new(process, policy, nil, publisher):apply()
        local generated = false
        for _, call in ipairs(calls) do
            if call.name == "publish" and call.args[1] == policy.usbguardRules and call.args[3] == "600" then generated = true end
        end
        assert(generated)
    end)
    suite:test("security stack verification checks managed files and enabled services", function()
        local process, _, publisher = fixture()
        assert(Stack.new(process, policy, nil, publisher):verify())
    end)
    suite:test("security package query errors fail before any provisioning mutation", function()
        local process, calls = fixture({ missingPackages = true, queryFailure = true })
        suite:reject(function() Stack.new(process, policy):apply() end)
        for _, call in ipairs(calls) do assert(call.name ~= "publish" and call.name ~= "unitEnable") end
    end)
end
