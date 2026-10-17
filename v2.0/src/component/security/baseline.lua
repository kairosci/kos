local Baseline = {}
Baseline.__index = Baseline

function Baseline.new(process, policy)
    return setmetatable({ process = assert(process), policy = assert(policy) }, Baseline)
end

function Baseline:verify(name)
    if name == "apparmor_kernel" then return self:_apparmorKernel() end
    local absentPath = self.policy.absentFiles[name]
    if absentPath then
        local exists = self.process:status("pathExists", { absentPath })
        return exists == 1
    end
    local permission = self.policy.permissions[name]
    if permission then
        local mode = tonumber(self.process:run("fileMode", { permission[1] }), 16)
        return mode ~= nil and mode & 0x1FF == tonumber(permission[2], 8)
    end
    local moduleFile = self.policy.moduleFiles[name]
    if moduleFile then
        local content, status = self.process:capture("securityFilePrivileged", { moduleFile[1] })
        return status == 0 and content == moduleFile[2]
    end
    error("unknown_security_baseline_check")
end

function Baseline:_apparmorKernel()
    local commandLine, commandStatus = self.process:capture("securityFilePrivileged", { "/proc/cmdline" })
    if commandStatus ~= 0 then return false end
    local enabled = false
    for argument in commandLine:gmatch("%S+") do
        local list = argument:match("^lsm=(.+)$")
        if list then
            for module in list:gmatch("[^,]+") do enabled = enabled or module == "apparmor" end
        end
    end
    return enabled and self.process:status("isReadable", { "/sys/kernel/security/apparmor/profiles" }) == 0
end

return Baseline
