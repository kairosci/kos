local Firewall = {}
Firewall.__index = Firewall

function Firewall.new(process, policy, catalog)
    return setmetatable({ process = assert(process), policy = assert(policy), catalog = catalog }, Firewall)
end

function Firewall:apply()
    local process, policy = self.process, self.policy
    assert(process:run("identity"):match("^0%s*$"), "root_required")
    local package = assert(policy.package)
    assert(package:match("^[a-z0-9][a-z0-9+_.-]*$"), "invalid_firewall_package")
    local installedPackage, installed = process:capture("pacmanInstalled", { package })
    assert(installed == 0 or installed == 1, "pacman_query_failed")
    if installed == 0 then
        assert(installedPackage:gsub("%s+$", "") == package, "pacman_package_mismatch")
    else
        process:run("pacmanInstall", { package })
    end

    assert(policy.defaults.incoming == "deny" and policy.defaults.outgoing == "allow", "invalid_firewall_defaults")
    process:run("ufwDefault", { policy.defaults.incoming, "incoming" })
    process:run("ufwDefault", { policy.defaults.outgoing, "outgoing" })
    for _, rule in ipairs(policy.ports) do
        assert(rule:match("^%d+/tcp$") or rule:match("^%d+/udp$"), "invalid_firewall_port")
        process:run("ufwAllow", { rule })
    end
    for _, path in ipairs(policy.rulesFiles) do
        assert(path:sub(1, 1) == "/", "absolute_firewall_rules_path_required")
        local link = process:status("isLink", { path })
        assert(link == 0 or link == 1, "firewall_rules_probe_failed")
        assert(link == 1, "redirected_firewall_rules")
        local exists = process:status("pathExists", { path })
        assert(exists == 0 or exists == 1, "firewall_rules_probe_failed")
        if exists == 0 then
            process:run("permissions", { "640", path })
        end
    end

    if process:status("ufwEnable") ~= 0 and self.catalog then
        io.stderr:write(self.catalog:text("firewall.already_active"), "\n")
    end
    if process:status("firewallServiceEnable") ~= 0 and self.catalog then
        io.stderr:write(self.catalog:text("firewall.service_enabled"), "\n")
    end
end

function Firewall:verify()
    local status, statusCode = self.process:capture("ufwStatusPrivileged")
    local verbose, verboseCode = self.process:capture("ufwStatusVerbosePrivileged")
    local enabled = self.process:status("firewallServiceEnabledPrivileged")
    if statusCode ~= 0 or verboseCode ~= 0 or enabled ~= 0 then return false end
    if not status:find("Status: active", 1, true) then return false end
    if not verbose:find("Default: deny (incoming)", 1, true) then return false end
    if not verbose:find("allow (outgoing)", 1, true) then return false end
    for _, rule in ipairs(self.policy.ports) do
        if not status:find(rule, 1, true) then return false end
    end
    return true
end

return Firewall
