local File = require("core.file")
local Firewall = require("component.security.firewall")

return function(suite, root)
    local policy = File.json(root .. "/data/component/security/firewall.json")

    local function fixture(options)
        options = options or {}
        local calls = {}
        local process = {
            run = function(_, name, arguments)
                calls[#calls + 1] = { name = name, arguments = arguments }
                if name == "identity" then return "0\n" end
                if name == "pacmanInstall" or name == "ufwDefault" or name == "ufwAllow" then return "" end
                error("unexpected_run_" .. name)
            end,
            capture = function(_, name)
                if name == "pacmanInstalled" then return options.installed and "ufw\n" or "", options.installed and 0 or 1 end
                if name == "ufwStatusPrivileged" then return options.status or "Status: active\n53317/udp ALLOW IN\n53317/tcp ALLOW IN\n", options.statusCode or 0 end
                if name == "ufwStatusVerbosePrivileged" then
                    return options.verbose or "Default: deny (incoming), allow (outgoing)\n", options.verboseCode or 0
                end
                error("unexpected_capture_" .. name)
            end,
            status = function(_, name)
                if name == "pathExists" or name == "isLink" then return 1 end
                if name == "ufwEnable" or name == "firewallServiceEnable" then return options.applyStatus or 0 end
                if name == "firewallServiceEnabledPrivileged" then return options.enabledStatus or 0 end
                error("unexpected_status_" .. name)
            end,
        }
        return process, calls
    end

    suite:test("firewall policy preserves incoming deny outgoing allow and explicit service ports", function()
        assert(policy.package == "ufw")
        assert(policy.defaults.incoming == "deny" and policy.defaults.outgoing == "allow")
        assert(table.concat(policy.ports, ",") == "53317/udp,53317/tcp")
        assert(#policy.rulesFiles == 6)
    end)

    suite:test("firewall apply installs UFW only when missing and preserves existing rules", function()
        local process, calls = fixture({})
        Firewall.new(process, policy):apply()
        local installs, defaults, allows = 0, 0, 0
        for _, call in ipairs(calls) do
            if call.name == "pacmanInstall" then installs = installs + 1 end
            if call.name == "ufwDefault" then defaults = defaults + 1 end
            if call.name == "ufwAllow" then allows = allows + 1 end
            assert(call.name ~= "ufwReset")
        end
        assert(installs == 1 and defaults == 2 and allows == 2)
    end)

    suite:test("firewall apply rejects non-root identities and symlinked owned rules", function()
        local process = fixture({})
        process.run = function(_, name)
            if name == "identity" then return "1000\n" end
            error("unexpected_run_" .. name)
        end
        suite:reject(function() Firewall.new(process, policy):apply() end)

        process = fixture({})
        process.status = function(_, name)
            if name == "pathExists" then return 1 end
            if name == "isLink" then return 0 end
            return 0
        end
        suite:reject(function() Firewall.new(process, policy):apply() end)
    end)

    suite:test("firewall verification checks active defaults rules and boot enablement", function()
        local process = fixture({})
        assert(Firewall.new(process, policy):verify())
        process = fixture({ status = "Status: inactive\n" })
        assert(not Firewall.new(process, policy):verify())
        process = fixture({ verbose = "Default: allow (incoming), allow (outgoing)\n" })
        assert(not Firewall.new(process, policy):verify())
        process = fixture({ enabledStatus = 1 })
        assert(not Firewall.new(process, policy):verify())
    end)
end
