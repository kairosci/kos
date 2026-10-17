local Publisher = require("core.publisher")

local Resolver = {}
Resolver.__index = Resolver

function Resolver.new(process, policy, catalog, publisher)
    return setmetatable({ process = assert(process), policy = assert(policy), catalog = catalog, publisher = publisher or Publisher }, Resolver)
end

function Resolver:apply()
    assert(self.process:run("identity"):match("^0%s*$"), "root_required")
    local provider = self:_provider()
    self:_writeProviderConfig(provider)
    for path, content in pairs(self.policy.files) do self.publisher.new(self.process):publish(path, content, "644") end
    self.process:run("systemdDaemonReload")
    self.process:run("systemdUnitRestart", { "systemd-resolved.service" })
    self.process:run("systemdUnitEnableNow", { "os-resolver-failover.service" })
    self.process:run("systemdUnitTryRestart", { "os-resolver-failover.service" })
end

function Resolver:verify()
    for path, expected in pairs(self.policy.files) do
        local content, status = self.process:capture("securityFilePrivileged", { path })
        if status ~= 0 or content ~= expected then return false end
    end
    local provider = self:_provider()
    local expected = "[Resolve]\nDNS=" .. table.concat(assert(self.policy.providerAddresses[provider]), " ") .. "\n"
    local content, status = self.process:capture("securityFilePrivileged", { self.policy.resolverConfiguration })
    return status == 0 and content == expected
        and self.process:status("systemdUnitEnabled", { "os-resolver-failover.service" }) == 0
        and self.process:status("systemdUnitActive", { "os-resolver-failover.service" }) == 0
end

function Resolver:_writeState(name, value)
    local directory = self.policy.stateDirectory
    self.process:run("directory", { directory })
    local path = directory .. "/" .. name
    local temporary = self.process:run("temporary", { directory .. "/.state.XXXXXX" }):gsub("\n$", "")
    local ok, failure = pcall(function()
        local file = assert(io.open(temporary, "wb"))
        assert(file:write(tostring(value), "\n"))
        assert(file:close())
        self.process:run("permissions", { "644", temporary })
        assert(os.rename(temporary, path))
    end)
    if not ok then
        local removed, removeFailure = os.remove(temporary)
        assert(removed, removeFailure)
        error(failure)
    end
end

function Resolver:_readState(name, default)
    local path = self.policy.stateDirectory .. "/" .. name
    local exists = self.process:status("pathExists", { path })
    assert(exists == 0 or exists == 1, "resolver_state_probe_failed")
    if exists == 1 then return default end
    local file = assert(io.open(path, "rb"))
    local value, readFailure = file:read("*l")
    assert(file:close())
    assert(value, readFailure)
    return value
end

function Resolver:_resetFailures()
    self:_writeState(self.policy.failureFile, 0)
end

function Resolver:_connected()
    local state, stateCode = self.process:capture("networkState")
    if stateCode ~= 0 or not state:match("^connected") then return false end
    local connectivity, connectivityCode = self.process:capture("networkConnectivity")
    return connectivityCode == 0 and (connectivity:match("^full$") or connectivity:match("^limited$")) ~= nil
end

function Resolver:_probe()
    for _, host in ipairs(self.policy.probeHosts) do
        if self.process:status("resolverProbe", { host }) == 0 then return true end
    end
    return false
end

function Resolver:_provider()
    local value = self:_readState(self.policy.providerFile, "Cloudflare")
    for _, provider in ipairs(self.policy.providers) do if value == provider then return value end end
    error("invalid_resolver_provider")
end

function Resolver:_writeProviderConfig(provider)
    local addresses = assert(self.policy.providerAddresses[provider], "unsupported_resolver_provider")
    local content = "[Resolve]\nDNS=" .. table.concat(addresses, " ") .. "\n"
    self.publisher.new(self.process):publish(self.policy.resolverConfiguration, content, "644")
end

function Resolver:_nextProvider(current)
    if current == "Cloudflare" then return "Google" end
    if current == "Google" then return "Cloudflare" end
    error("invalid_resolver_provider")
end

function Resolver:_cooldown()
    local raw = self:_readState(self.policy.lastSwitchFile, nil)
    if raw == nil then return false end
    local last = tonumber(raw)
    assert(last and last >= 0 and last % 1 == 0, "invalid_resolver_timestamp")
    local now = os.time()
    assert(now >= last, "future_resolver_timestamp")
    return now - last < self.policy.cooldownSeconds
end

function Resolver:checkOnce()
    if not self:_connected() then
        self:_resetFailures()
        self:_log("dns.offline")
        return true
    end
    if self:_probe() then
        self:_resetFailures()
        return true
    end
    local count = tonumber(self:_readState(self.policy.failureFile, "0"))
    assert(count and count >= 0 and count % 1 == 0, "invalid_resolver_failure_count")
    count = math.min(count + 1, self.policy.failureLimit)
    self:_writeState(self.policy.failureFile, count)
    if count < self.policy.failureLimit then
        self:_warn("dns.probe_failed", count, self.policy.failureLimit)
        return true
    end
    if self:_cooldown() then
        self:_log("dns.cooldown")
        return true
    end
    local current = self:_provider()
    local nextProvider = self:_nextProvider(current)
    local ok, failure = pcall(function()
        self:_writeProviderConfig(nextProvider)
        self.process:run("systemdUnitRestart", { "systemd-resolved.service" })
    end)
    if not ok then
        self:_resetFailures()
        self:_warn("dns.switch_failed", current, nextProvider)
        return false
    end
    self:_writeState(self.policy.providerFile, nextProvider)
    self:_writeState(self.policy.lastSwitchFile, os.time())
    self:_resetFailures()
    for attempt = 1, 3 do
        if self:_probe() then
            self:_log("dns.switched", current, nextProvider)
            return true
        end
        if attempt < 3 then self.process:status("sleep", { "2" }) end
    end
    self:_warn("dns.fallback_unavailable", nextProvider)
    return false
end

function Resolver:_log(key, ...)
    if self.catalog then io.stdout:write(self.catalog:text(key, ...), "\n") end
end

function Resolver:_warn(key, ...)
    if self.catalog then io.stderr:write(self.catalog:text(key, ...), "\n") end
end

function Resolver:run()
    while true do
        local ok, result = pcall(function() return self:checkOnce() end)
        if not ok or not result then self:_warn("dns.health_check_failed") end
        self.process:status("sleep", { "60" })
    end
end

return Resolver
