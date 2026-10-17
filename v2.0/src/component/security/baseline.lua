local Baseline = {}
Baseline.__index = Baseline

function Baseline.new(process, policy, publisher)
    return setmetatable({ process = assert(process), policy = assert(policy), publisher = publisher or require("core.publisher") }, Baseline)
end

function Baseline:apply()
    assert(self.process:run("identity"):match("^0%s*$"), "root_required")
    local names = {}
    for name in pairs(self.policy.moduleFiles) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local file = self.policy.moduleFiles[name]
        self.publisher.new(self.process):publish(file[1], file[2], "644")
    end
    names = {}
    for name in pairs(self.policy.permissions) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local permission = self.policy.permissions[name]
        assert(permission[2]:match("^[0-7][0-7][0-7]$"), "invalid_security_mode")
        self.process:run("permissions", { permission[2], permission[1] })
    end
    self:_applySshPermissions()
end

function Baseline:_applySshPermissions()
    local policy = self.policy.sshPermissions
    self.process:run("permissions", { policy.directory[2], policy.directory[1] })
    local output, status = self.process:capture("findFiles", {
        "/etc/ssh", "-maxdepth", tostring(policy.maxDepth), "-type", "f", "-print0"
    })
    assert(status == 0, "ssh_file_inventory_failed")
    local files = {}
    for path in output:gmatch("([^%z]+)%z?") do files[#files + 1] = path end
    table.sort(files)
    for _, path in ipairs(files) do
        local mode
        for _, root in ipairs(policy.serverFiles) do
            if path == root or path:sub(1, #root + 1) == root .. "/" then mode = "600" end
        end
        for _, root in ipairs(policy.clientFiles) do
            if path == root or path:sub(1, #root + 1) == root .. "/" then mode = "644" end
        end
        if mode then self.process:run("permissions", { mode, path }) end
    end
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
