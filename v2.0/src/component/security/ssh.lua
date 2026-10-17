local SSH = {}
SSH.__index = SSH

function SSH.new(process, policy, catalog, publisher)
    return setmetatable({
        process = assert(process),
        policy = assert(policy),
        catalog = catalog,
        publisher = publisher or require("core.publisher").new(process),
    }, SSH)
end

function SSH:apply()
    local process = self.process
    assert(process:run("identity"):match("^0%s*$"), "root_required")
    for _, file in ipairs(self.policy.files) do
        local validator
        if file.validator then
            validator = function(path) process:run(file.validator, { path }) end
        end
        self.publisher:publish(file.path, file.content, file.mode, validator)
    end
    process:run("systemdDaemonReload")
    if process:status("sshdActive") == 0 then
        process:run("sshdValidate", { "/etc/ssh/sshd_config" })
        if process:status("sshdRestart") ~= 0 and self.catalog then
            io.stderr:write(self.catalog:text("ssh.restart_failed"), "\n")
        end
    end
end

function SSH:verify()
    for _, file in ipairs(self.policy.files) do
        local content, status = self.process:capture("securityFilePrivileged", { file.path })
        if status ~= 0 or content ~= file.content then return false end
    end
    return true
end

return SSH
