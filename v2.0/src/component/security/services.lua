local Publisher = require("core.publisher")

local Services = {}
Services.__index = Services

function Services.new(process, policy, catalog, publisher)
    return setmetatable({ process = assert(process), policy = assert(policy), catalog = catalog, publisher = publisher or Publisher }, Services)
end

function Services:apply()
    local process = self.process
    assert(process:run("identity"):match("^0%s*$"), "root_required")
    for path, content in pairs(self.policy.files) do
        self.publisher.new(process):publish(path, content, "644")
    end
    local status = process:status("systemdDaemonReload")
    assert(status == 0, "systemd_daemon_reload_failed")
    if process:status("journaldRestart") ~= 0 and self.catalog then
        io.stderr:write(self.catalog:text("services.journald_restart"), "\n")
    end
    for _, unit in ipairs(self.policy.units) do
        local output, code = process:capture("systemdUnitFiles", { unit })
        assert(code == 0, "systemd_unit_query_failed")
        if output:match("%S") then
            local disabled = process:status("systemdDisableUnit", { unit })
            if disabled ~= 0 and self.catalog then
                local key = unit:match("%.socket$") and "services.socket_missing" or "services.missing"
                io.stderr:write(self.catalog:text(key, unit:gsub("%.%w+$", "")), "\n")
            end
        end
    end
end

function Services:verify()
    local process = self.process
    for path, expected in pairs(self.policy.files) do
        local content, code = process:capture("securityFilePrivileged", { path })
        if code ~= 0 or content ~= expected then return false end
    end
    for _, unit in ipairs(self.policy.units) do
        local listed, listCode = process:capture("systemdUnitFilesPrivileged", { unit })
        if listCode ~= 0 then return false end
        if listed:match("%S") then
            local enabled, enableCode = process:capture("systemdUnitEnabledPrivileged", { unit })
            if enableCode == 0 and enabled:match("^enabled%s*$") then return false end
            if enableCode ~= 0 then
                local state = enabled:match("^(%S+)%s*$")
                local allowed = {
                    disabled = true, static = true, indirect = true, masked = true,
                    generated = true, transient = true, alias = true, linked = true,
                    ["linked-runtime"] = true, ["not-found"] = true,
                }
                if not allowed[state] then return false end
            end
        end
    end
    for _, path in ipairs(self.policy.forbiddenFiles or {}) do
        local exists = process:status("pathExists", { path })
        if exists ~= 0 and exists ~= 1 then return false end
        if exists == 0 then return false end
    end
    return true
end

return Services
