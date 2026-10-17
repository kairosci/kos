local File = require("core.file")
local Publisher = require("core.publisher")
local Kernel = {}
Kernel.__index = Kernel

function Kernel.new(process, policy, catalog, adapters)
    adapters = adapters or {}
    return setmetatable({
        process = assert(process),
        policy = assert(policy),
        catalog = catalog,
        publisher = adapters.publisher or Publisher.new(process),
        read_file = adapters.read_file or File.read,
    }, Kernel)
end

function Kernel:apply()
    local process = self.process
    assert(process:run("identity"):match("^0%s*$"), "root_required")
    for _, file in ipairs(self.policy.files) do
        assert(file.path:sub(1, 1) == "/", "absolute_kernel_policy_path_required")
        assert(file.mode == "644" and type(file.content) == "string", "invalid_kernel_policy_file")
        self.publisher:publish(file.path, file.content, file.mode)
    end
    if process:status("sysctlSystem") ~= 0 and self.catalog then
        io.stderr:write(self.catalog:text("kernel.sysctl_partial"), "\n")
    end
end

function Kernel:verify()
    local process = self.process
    for _, file in ipairs(self.policy.files) do
        local ok, content = pcall(self.read_file, file.path)
        if not ok or content ~= file.content then return false end
    end
    for _, setting in ipairs(self.policy.verification) do
        local output, status = process:capture("sysctlPrivileged", { "-n", setting[1] })
        if status ~= 0 or output:gsub("%s+$", "") ~= setting[2] then return false end
    end
    return true
end

return Kernel
