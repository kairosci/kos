local File = require("core.file")
local Authentication = require("component.security.authentication")
local SSH = require("component.security.ssh")

return function(suite, root)
    local authPolicy = File.json(root .. "/data/component/security/authentication.json")
    local sshPolicy = File.json(root .. "/data/component/security/ssh.json")
    local pamSource = table.concat({
        "# preserved policy comment",
        "auth required pam_faillock.so preauth silent deny=10 unlock_time=120 conf=/etc/security/faillock.conf",
        "auth [default=die] pam_faillock.so authfail deny=10 unlock_time=120",
        "auth required pam_unix.so try_first_pass nullok",
        "-password [success=1 default=ignore] pam_systemd_home.so",
        "password required pam_unix.so try_first_pass nullok shadow",
        "session required pam_unix.so",
        "",
    }, "\n")

    suite:test("PAM migration removes inline overrides and preserves required controls", function()
        local transformed = Authentication.transform(pamSource, authPolicy.pamQualityLine)
        assert(not transformed:find("deny=10", 1, true))
        assert(not transformed:find("unlock_time=120", 1, true))
        assert(not transformed:find("nullok", 1, true))
        assert(transformed:find(authPolicy.pamQualityLine, 1, true))
        assert(transformed:find("pam_unix.so try_first_pass shadow use_authtok", 1, true))
        assert(Authentication.transform(transformed, authPolicy.pamQualityLine) == transformed)
        assert(transformed:find("# preserved policy comment", 1, true))
    end)

    suite:test("PAM migration rejects unsupported stacks without producing output", function()
        suite:reject(function()
            Authentication.transform("auth required pam_unix.so\n", authPolicy.pamQualityLine)
        end)
    end)

    suite:test("authentication apply installs dependencies and publishes canonical policy", function()
        local calls, published, pam = {}, {}, {}
        local process = {
            run = function(_, name)
                calls[#calls + 1] = name
                if name == "identity" then return "0\n" end
                if name == "pacmanInstall" then return "" end
                error("unexpected_run_" .. name)
            end,
            capture = function(_, name)
                assert(name == "pacmanInstalled")
                return "", 1
            end,
            status = function(_, name)
                assert(name == "isLink")
                return 1
            end,
        }
        local adapter = { publish = function(_, path, content, mode)
            published[#published + 1] = { path = path, content = content, mode = mode }
        end }
        Authentication.new(process, authPolicy, nil, {
            publisher = adapter,
            read_file = function(path)
                assert(path == authPolicy.pamPath)
                return pamSource
            end,
            pam_adapter = function(path, line) pam = { path, line } end,
        }):apply()
        assert(#published == #authPolicy.files and calls[2] == "pacmanInstall")
        assert(pam[1] == authPolicy.pamPath and pam[2] == authPolicy.pamQualityLine)
    end)

    suite:test("authentication verification detects content drift", function()
        local expectedPam = Authentication.transform(pamSource, authPolicy.pamQualityLine)
        local contents = { [authPolicy.pamPath] = expectedPam }
        for _, file in ipairs(authPolicy.files) do contents[file.path] = file.content end
        local process = { capture = function(_, name, arguments)
            if name == "pacmanInstalled" then return authPolicy.package .. "\n", 0 end
            assert(name == "securityFilePrivileged")
            if contents[arguments[1]] then return contents[arguments[1]], 0 end
            return "", 1
        end }
        local authentication = Authentication.new(process, authPolicy)
        assert(authentication:verify())
        contents[authPolicy.files[1].path] = "deny = 2\n"
        assert(not authentication:verify())
    end)

    suite:test("PAM publication is atomic, keeps one original backup and is idempotent", function()
        local target = os.tmpname()
        local backup = target .. ".os-backup"
        local sourceFile = assert(io.open(target, "wb"))
        assert(sourceFile:write(pamSource))
        assert(sourceFile:close())
        local process = {
            status = function(_, name, arguments)
                if name == "isLink" then return 1 end
                if name == "pathExists" then
                    local handle = io.open(arguments[1], "rb")
                    if handle then handle:close(); return 0 end
                    return 1
                end
                error("unexpected_status_" .. name)
            end,
            run = function(_, name, arguments)
                if name == "temporary" then return os.tmpname() end
                if name == "permissionsReference" or name == "ownershipReference" then return "" end
                if name == "copyPreserve" then
                    local original = assert(io.open(arguments[1], "rb"))
                    local content = assert(original:read("a"))
                    assert(original:close())
                    local copy = assert(io.open(arguments[2], "wb"))
                    assert(copy:write(content))
                    assert(copy:close())
                    return ""
                end
                if name == "move" then assert(os.rename(arguments[1], arguments[2])); return "" end
                error("unexpected_run_" .. name)
            end,
        }
        local authPolicyFixture = {}
        for key, value in pairs(authPolicy) do authPolicyFixture[key] = value end
        authPolicyFixture.pamPath = target
        local authentication = Authentication.new(process, authPolicyFixture)
        local original = pamSource
        local _, transformed = authentication:prepare_pam()
        assert(authentication:reconcile_pam(original, transformed))
        local migrated = File.read(target)
        assert(migrated == transformed and File.read(backup) == original)
        assert(not authentication:reconcile_pam(migrated, transformed))
        assert(File.read(target) == migrated and File.read(backup) == original)
        assert(os.remove(target) and os.remove(backup))
    end)

    suite:test("SSH application validates each staged policy and restarts only an active daemon", function()
        local published, calls = {}, {}
        local process = {
            run = function(_, name, arguments)
                calls[#calls + 1] = { name = name, arguments = arguments }
                if name == "identity" then return "0\n" end
                return ""
            end,
            status = function(_, name)
                calls[#calls + 1] = { name = name }
                return name == "sshdActive" and 0 or 0
            end,
        }
        local publisher = { publish = function(_, path, content, mode, validator)
            published[#published + 1] = { path = path, content = content, mode = mode }
            if validator then validator("/tmp/staged") end
        end }
        SSH.new(process, sshPolicy, nil, publisher):apply()
        assert(#published == #sshPolicy.files)
        local sshValidators, systemdValidators = 0, 0
        for _, call in ipairs(calls) do
            if call.name == "sshdValidate" then sshValidators = sshValidators + 1 end
            if call.name == "systemdVerify" then systemdValidators = systemdValidators + 1 end
        end
        assert(sshValidators == 2 and systemdValidators == 0)
        assert(calls[#calls].name == "sshdRestart")
    end)

    suite:test("SSH verification compares all owned files", function()
        local process = { capture = function(_, name, arguments)
            assert(name == "securityFilePrivileged")
            for _, file in ipairs(sshPolicy.files) do
                if file.path == arguments[1] then return file.content, 0 end
            end
            return "", 1
        end }
        assert(SSH.new(process, sshPolicy):verify())
    end)
end
