local File = require("core.file")
local Process = require("core.process")
local Resolver = require("component.security.resolver")

return function(suite, root)
    local policy = File.json(root .. "/data/component/security/resolver.json")
    local real = Process.new(File.json(root .. "/data/core/commands.json"))
    local function fixture(options)
        options = options or {}
        local directory = real:run("temporary", { "-d" }):gsub("\n$", "")
        local currentPolicy = File.json(root .. "/data/component/security/resolver.json")
        currentPolicy.stateDirectory = directory
        local calls = {}
        local process = {
            run = function(_, name, arguments)
                calls[#calls + 1] = { name = name, arguments = arguments }
                if name == "identity" then return "0\n" end
                if name == "systemdDaemonReload" or name == "systemdUnitEnableNow" or name == "systemdUnitTryRestart" or name == "systemdUnitRestart" then return "" end
                if name == "directory" and arguments[1] == "/etc/NetworkManager/conf.d" then return "" end
                return real:run(name, arguments)
            end,
            status = function(_, name, arguments)
                calls[#calls + 1] = { name = name, arguments = arguments }
                if name == "resolverProbe" then
                    local result = table.remove(options.probes or {}, 1)
                    return result or options.probe or 1
                end
                if name == "sleep" then return 0 end
                if name == "systemdUnitEnabled" or name == "systemdUnitActive" then return 0 end
                return real:status(name, arguments)
            end,
            capture = function(_, name, arguments)
                if name == "networkState" then return options.state or "connected\n", options.stateCode or 0 end
                if name == "networkConnectivity" then return options.connectivity or "full", options.connectivityCode or 0 end
                if name == "securityFilePrivileged" then return currentPolicy.files[arguments[1]] or "", 0 end
                return real:capture(name, arguments)
            end,
        }
        return process, currentPolicy, calls, directory
    end
    local function clean(directory)
        real:run("removeTree", { directory })
    end
    suite:test("resolver policy defines threshold, cooldown and the managed service", function()
        assert(policy.failureLimit == 3 and policy.cooldownSeconds == 900)
        assert(#policy.probeHosts == 3)
        assert(policy.files["/etc/systemd/system/os-resolver-failover.service"]:find("run-resolver-failover", 1, true))
    end)
    suite:test("healthy DNS resets recorded failures", function()
        local process, current, _, directory = fixture({ probe = 0 })
        local resolver = Resolver.new(process, current)
        resolver:_writeState(current.failureFile, 2)
        assert(resolver:checkOnce())
        assert(File.read(directory .. "/" .. current.failureFile) == "0\n")
        clean(directory)
    end)
    suite:test("offline connectivity clears stale failures without switching providers", function()
        local process, current, calls, directory = fixture({ state = "disconnected\n" })
        Resolver.new(process, current):_writeState(current.failureFile, 2)
        assert(Resolver.new(process, current):checkOnce())
        assert(File.read(directory .. "/" .. current.failureFile) == "0\n")
        for _, call in ipairs(calls) do assert(call.name ~= "systemdUnitRestart") end
        clean(directory)
    end)
    suite:test("three consecutive failed probes switch to the alternate provider", function()
        local process, current, calls, directory = fixture({ probes = { 1, 1, 1, 1, 1, 1, 1, 1, 1, 0 } })
        local publisher = { new = function() return { publish = function(_, path, content)
            calls[#calls + 1] = { name = "publish", arguments = { path, content } }
        end } end }
        local resolver = Resolver.new(process, current, nil, publisher)
        resolver:checkOnce()
        resolver:checkOnce()
        assert(resolver:checkOnce())
        local switched = false
        for _, call in ipairs(calls) do
            if call.name == "systemdUnitRestart" and call.arguments[1] == "systemd-resolved.service" then switched = true end
        end
        assert(switched and File.read(directory .. "/" .. current.failureFile) == "0\n")
        assert(File.read(directory .. "/" .. current.providerFile) == "Google\n")
        local config = false
        for _, call in ipairs(calls) do
            config = config or call.name == "publish" and call.arguments[1] == current.resolverConfiguration
                and call.arguments[2] == "[Resolve]\nDNS=8.8.8.8 8.8.4.4\n"
        end
        assert(config)
        clean(directory)
    end)
    suite:test("an invalid provider and a future cooldown timestamp fail closed", function()
        local process, current, _, directory = fixture({})
        local resolver = Resolver.new(process, current)
        resolver:_writeState(current.providerFile, "Unknown")
        suite:reject(function() resolver:_provider() end)
        suite:reject(function() resolver:_nextProvider("Unknown") end)
        resolver:_writeState(current.lastSwitchFile, os.time() + 1)
        suite:reject(function() resolver:_cooldown() end)
        clean(directory)
    end)
    suite:test("resolver service installation publishes the unit and enables the daemon", function()
        local process, current, calls = fixture({})
        local publisher = { new = function() return { publish = function() end } end }
        Resolver.new(process, current, nil, publisher):apply()
        local enabled, restarted = false, false
        for _, call in ipairs(calls) do
            enabled = enabled or call.name == "systemdUnitEnableNow"
            restarted = restarted or call.name == "systemdUnitTryRestart"
        end
        assert(enabled and restarted)
        local resolved = false
        for _, call in ipairs(calls) do
            resolved = resolved or call.name == "systemdUnitRestart" and call.arguments[1] == "systemd-resolved.service"
        end
        assert(resolved)
    end)
end
