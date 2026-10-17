local File = require("core.file")
local Publisher = require("core.publisher")
local Debloat = {}
Debloat.__index = Debloat

function Debloat.new(process, policy)
    return setmetatable({ process = assert(process), policy = assert(policy) }, Debloat)
end

function Debloat:apply()
    local process, policy = self.process, self.policy
    assert(process:run("identity"):match("^0%s*$"), "root_required")
    local configuration = policy.pacmanConfiguration
    assert(configuration:sub(1, 1) == "/", "absolute_pacman_configuration_required")
    assert(process:status("isLink", { configuration }) == 1, "redirected_pacman_configuration")
    local content = File.read(configuration)
    local filtered = content:gsub("([^\n]*\n?)", function(line)
        if line:match("^%s*IgnorePkg%s*=") then return "" end
        return line
    end)
    local pinList = policy.obsoletePinList
    assert(pinList:sub(1, 1) == "/", "absolute_pin_list_required")
    assert(process:status("isLink", { pinList }) == 1, "redirected_pin_list")
    local pinListExists = process:status("pathExists", { pinList })
    assert(pinListExists == 0 or pinListExists == 1, "pin_list_probe_failed")

    local installed = {}
    for _, package in ipairs(policy.removePackages) do
        assert(type(package) == "string" and package:match("^[a-z0-9][a-z0-9+_.-]*$"), "invalid_debloat_package")
        local output, status = process:capture("pacmanInstalled", { package })
        assert(status == 0 or status == 1, "pacman_query_failed")
        if status == 0 then
            assert(output:gsub("[\r\n]+$", "") == package, "invalid_pacman_query")
            installed[#installed + 1] = package
        end
    end
    if #installed > 0 then process:run("pacmanRemove", installed) end

    if filtered ~= content then
        local mode = assert(tonumber(process:run("fileMode", { configuration }), 16)) & 0x1ff
        Publisher.new(process):publish(configuration, filtered, string.format("%o", mode), nil, false)
    end

    if pinListExists == 0 then process:run("removeFile", { pinList }) end
    return #installed
end

return Debloat
