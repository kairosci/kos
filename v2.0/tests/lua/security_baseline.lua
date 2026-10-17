local File = require("core.file")
local Baseline = require("component.security.baseline")

return function(suite, root)
    local policy = File.json(root .. "/data/component/security/baseline.json")
    local function fixture(options)
        options = options or {}
        local operations = {}
        local process = {
            run = function(_, name, arguments)
                if name == "identity" then return (options.identity or 0) .. "\n" end
                if name == "permissions" then operations[#operations + 1] = { name = name, arguments = arguments }; return "" end
                assert(name == "fileMode")
                return options.modes and options.modes[arguments[1]] or "81a4\n"
            end,
            capture = function(_, name, arguments)
                if name == "findFiles" then return options.sshFiles or "", options.sshFindStatus or 0 end
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
        local publisher = { new = function()
            return { publish = function(_, path, content, mode)
                operations[#operations + 1] = { name = "publish", arguments = { path, content, mode } }
            end }
        end }
        return Baseline.new(process, policy, publisher), operations
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
    suite:test("baseline application publishes blacklists and applies privileged modes", function()
        local baseline, operations = fixture({ sshFiles = table.concat({
            "/etc/ssh/ssh_config\0", "/etc/ssh/sshd_config\0",
            "/etc/ssh/ssh_config.d/10-os.conf\0", "/etc/ssh/sshd_config.d/10-os.conf\0",
            "/etc/ssh/other.conf\0",
        }) })
        baseline:apply()
        local published, modes = 0, {}
        for _, operation in ipairs(operations) do
            if operation.name == "publish" then
                published = published + 1
                assert(policy.moduleFiles[operation.arguments[1] == policy.moduleFiles.usb_storage[1] and "usb_storage"
                    or operation.arguments[1] == policy.moduleFiles.protocols[1] and "protocols"
                    or operation.arguments[1] == policy.moduleFiles.firewire[1] and "firewire" or "filesystems"])
            else
                modes[operation.arguments[2]] = operation.arguments[1]
            end
        end
        assert(published == 4)
        for _, permission in pairs(policy.permissions) do assert(modes[permission[1]] == permission[2]) end
        assert(modes["/etc/ssh"] == "750")
        assert(modes["/etc/ssh/sshd_config"] == "600")
        assert(modes["/etc/ssh/sshd_config.d/10-os.conf"] == "600")
        assert(modes["/etc/ssh/ssh_config"] == "644")
        assert(modes["/etc/ssh/ssh_config.d/10-os.conf"] == "644")
        assert(modes["/etc/ssh/other.conf"] == nil)
    end)
    suite:test("baseline application refuses non-root identities before mutation", function()
        local baseline, operations = fixture({ identity = 1000 })
        suite:reject(function() baseline:apply() end)
        assert(#operations == 0)
    end)
    suite:test("SSH file inventory errors stop baseline application", function()
        local baseline = fixture({ sshFindStatus = 1 })
        suite:reject(function() baseline:apply() end)
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
