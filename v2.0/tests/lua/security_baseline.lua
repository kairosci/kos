local File = require("core.file")
local Baseline = require("component.security.baseline")

return function(suite, root)
    local policy = File.json(root .. "/data/component/security/baseline.json")
    local function fixture(options)
        options = options or {}
        local process = {
            run = function(_, name, arguments)
                assert(name == "fileMode")
                return options.modes and options.modes[arguments[1]] or "81a4\n"
            end,
            capture = function(_, name, arguments)
                assert(name == "securityFilePrivileged")
                if arguments[1] == "/proc/cmdline" then return options.commandLine or "quiet lsm=landlock,apparmor,bpf", options.commandStatus or 0 end
                for check, file in pairs(policy.moduleFiles) do
                    if arguments[1] == file[1] then return options.files and options.files[check] or file[2], 0 end
                end
                return "", 1
            end,
            status = function(_, name)
                if name == "isReadable" then return options.profilesReadable == false and 1 or 0 end
                if name == "pathExists" then return options.pathStatus or (options.verityPresent and 0 or 1) end
                error("unexpected_status_" .. name)
            end,
        }
        return Baseline.new(process, policy)
    end

    suite:test("security baseline policy covers permissions, blacklists and AppArmor boot", function()
        assert(policy.permissions.root[2] == "700")
        assert(policy.moduleFiles.usb_storage[2]:find("blacklist usb%-storage"))
    end)
    suite:test("file permissions match the declared octal mode", function()
        for _, name in ipairs({ "root", "shadow", "gshadow", "passwd", "group" }) do
            local entry = policy.permissions[name]
            local fileType = name == "root" and 0x4000 or 0x8000
            local mode = fileType | tonumber(entry[2], 8)
            local baseline = fixture({ modes = { [entry[1]] = string.format("%04x\n", mode) } })
            assert(baseline:verify(name))
        end
        assert(not fixture({ modes = { [policy.permissions.shadow[1]] = "81a4\n" } }):verify("shadow"))
    end)
    suite:test("module blacklist verification compares complete canonical content", function()
        local baseline = fixture()
        for name in pairs(policy.moduleFiles) do assert(baseline:verify(name)) end
        assert(not fixture({ files = { protocols = "blacklist dccp\n" } }):verify("protocols"))
    end)
    suite:test("AppArmor verification parses the LSM list and checks live profiles", function()
        assert(fixture():verify("apparmor_kernel"))
        assert(not fixture({ commandLine = "quiet lsm=landlock,bpf" }):verify("apparmor_kernel"))
        assert(not fixture({ profilesReadable = false }):verify("apparmor_kernel"))
        assert(not fixture({ commandStatus = 1 }):verify("apparmor_kernel"))
        assert(fixture():verify("tpm_verity_removed"))
        assert(not fixture({ verityPresent = true }):verify("tpm_verity_removed"))
        assert(not fixture({ pathStatus = 2 }):verify("tpm_verity_removed"))
    end)
    suite:test("unknown security baseline checks fail explicitly", function()
        suite:reject(function() fixture():verify("unknown") end)
    end)
end
