local Publisher = require("core.publisher")

local Stack = {}
Stack.__index = Stack

function Stack.new(process, policy, catalog, publisher)
    return setmetatable({ process = assert(process), policy = assert(policy), catalog = catalog, publisher = publisher or Publisher }, Stack)
end

function Stack:apply()
    local process, policy = self.process, self.policy
    assert(process:run("identity"):match("^0%s*$"), "root_required")
    for _, package in ipairs(policy.packages) do
        local installed = process:status("pacmanInstalled", { package })
        assert(installed == 0 or installed ~= 0, "pacman_query_failed")
        if installed ~= 0 then
            local available = process:status("pacmanInfo", { package })
            if available == 0 then
                local status = process:status("pacmanInstall", { package })
                if status ~= 0 and self.catalog then io.stderr:write(self.catalog:text("security.pkg_failed", package), "\n") end
            elseif self.catalog then
                io.stderr:write(self.catalog:text("security.pkg_missing", package), "\n")
            end
        end
    end

    for path, content in pairs(policy.files) do self.publisher.new(process):publish(path, content, "644") end
    for package, files in pairs(policy.packageFiles) do
        if process:status("pacmanInstalled", { package }) == 0 then
            for path, content in pairs(files) do self.publisher.new(process):publish(path, content, "644") end
        end
    end
    process:run("systemdDaemonReload")
    if process:status("systemdUnitFiles", { "auditd.service" }) == 0 then
        if process:status("unitEnable", { "auditd.service" }) ~= 0 and self.catalog then
            io.stderr:write(self.catalog:text("security.audit_enable_skipped"), "\n")
        end
        if process:status("systemdUnitActive", { "auditd.service" }) == 0 then
            local load = process:status("isExecutable", { "/usr/bin/augenrules" }) == 0
                and process:status("auditRulesLoad")
                or process:status("auditRulesFallback", { policy.auditRules })
            if load ~= 0 and self.catalog then io.stderr:write(self.catalog:text("security.audit_load_skipped"), "\n") end
        elseif process:status("unitStart", { "auditd.service" }) ~= 0 and self.catalog then
            io.stderr:write(self.catalog:text("security.audit_restart_skipped"), "\n")
        end
    end

    if process:status("pacmanInstalled", { "usbguard" }) == 0 then
        local previous = self.publisher.new(process):inspect(policy.usbguardRules)
        if not previous or not previous:match("%S") then
            local generated = process:run("usbguardGenerate")
            self.publisher.new(process):publish(policy.usbguardRules, generated, "600")
        end
        process:run("permissions", { "600", policy.usbguardRules })
        if process:status("unitEnable", { "usbguard.service" }) ~= 0 and self.catalog then
            io.stderr:write(self.catalog:text("security.usbguard_enable_failed"), "\n")
        end
    end

    if process:status("pacmanInstalled", { "clamav" }) == 0 then
        if process:status("unitEnable", { "clamav-freshclam.service" }) ~= 0 and self.catalog then
            io.stderr:write(self.catalog:text("security.clamav_freshclam_failed"), "\n")
        end
        if process:status("unitEnable", { "clamav-daemon.service" }) ~= 0 and self.catalog then
            io.stderr:write(self.catalog:text("security.clamav_daemon_failed"), "\n")
        end
        if process:status("freshclamRunning") ~= 0 then
            if process:status("freshclamUpdate") ~= 0 and self.catalog then
                io.stderr:write(self.catalog:text("security.clamav_update_skipped"), "\n")
            end
        elseif self.catalog then
            io.stderr:write(self.catalog:text("security.clamav_update_deferred"), "\n")
        end
    end
    if process:status("pacmanInstalled", { "fail2ban" }) == 0
        and process:status("unitEnable", { "fail2ban.service" }) ~= 0 and self.catalog then
        io.stderr:write(self.catalog:text("security.fail2ban_enable_failed"), "\n")
    end
    if process:status("pacmanInstalled", { "apparmor" }) == 0 then
        if process:status("grubMenuUpdate") ~= 0 and self.catalog then
            io.stderr:write(self.catalog:text("security.apparmor_failed"), "\n")
        end
        for _, path in ipairs(policy.profiles) do process:run("permissions", { "644", path }) end
        if process:status("unitEnable", { "apparmor.service" }) ~= 0 and self.catalog then
            io.stderr:write(self.catalog:text("security.apparmor_failed"), "\n")
        end
        for _, entry in ipairs({
            { "/usr/bin/sshd", "security.aa_sshd" },
            { "/usr/bin/useradd", "security.aa_useradd" },
            { "/usr/bin/curl", "security.aa_curl" },
            { "/usr/bin/wget", "security.aa_wget" },
        }) do
            if process:status("apparmorEnforce", { entry[1] }) ~= 0 and self.catalog then
                io.stderr:write(self.catalog:text(entry[2]), "\n")
            end
        end
    end
end

function Stack:verify()
    local process, policy = self.process, self.policy
    for _, package in ipairs(policy.packages) do if process:status("pacmanInstalled", { package }) ~= 0 then return false end end
    local files = {}
    for path, content in pairs(policy.files) do files[path] = content end
    for _, group in pairs(policy.packageFiles) do for path, content in pairs(group) do files[path] = content end end
    for path, expected in pairs(files) do
        local content, status = process:capture("securityFilePrivileged", { path })
        if status ~= 0 or content ~= expected then return false end
        local mode = tonumber(process:run("fileMode", { path }), 16)
        if not mode or mode & 0x1FF ~= 0x1A4 then return false end
    end
    local rules, status = process:capture("securityFilePrivileged", { policy.usbguardRules })
    if status ~= 0 or not rules:match("%S") then return false end
    local mode = tonumber(process:run("fileMode", { policy.usbguardRules }), 16)
    if not mode or mode & 0x1FF ~= 0x180 then return false end
    for _, unit in ipairs({ "auditd.service", "usbguard.service", "clamav-freshclam.service", "clamav-daemon.service", "fail2ban.service", "apparmor.service" }) do
        if process:status("systemdUnitEnabled", { unit }) ~= 0 then return false end
    end
    for _, path in ipairs(policy.profiles) do
        local content, code = process:capture("securityFilePrivileged", { path })
        if code ~= 0 or not content:find("#include <tunables/global>", 1, true) then return false end
    end
    return true
end

return Stack
