local File = require("core.file")
local Json = require("core.json")
local Paths = require("core.paths")
local Installer = require("component.cli.installer")

return function(suite, root, process)
    local directory = process:run("temporary", { "-d" }):gsub("\n$", "")
    local home = directory .. "/home"
    local function write(path, content)
        process:run("directory", { assert(path:match("^(.*)/[^/]+$")) })
        local handle = assert(io.open(path, "wb"))
        assert(handle:write(content))
        assert(handle:close())
    end
    local policy = File.json(root .. "/data/component/cli/installation.json")
    policy.systemDataRoot = directory .. "/share"
    policy.systemExecutable = directory .. "/bin/os"
    policy.systemChangelog = directory .. "/share/os/CHANGELOG.md"
    policy.legacyCatalogDirectory = directory .. "/share/os/lib/messages"
    for _, entry in ipairs(policy.legacyFiles) do
        entry.destination = directory .. "/share/os/lib/i18n.sh"
    end
    local paths = Paths.new(File.json(root .. "/data/core/paths.json"), function(name)
        if name == "HOME" then return home end
    end)
    local backend = {
        run = function(_, name, args)
            if name == "identity" then return "0\n" end
            return process:run(name, args)
        end,
        status = function(_, name, args)
            return process:status(name, args)
        end,
    }
    local installer = Installer.new(root, backend, policy, paths)
    local active = policy.systemDataRoot .. "/" .. policy.runtime .. "/" .. policy.runtimeCurrent
    write(policy.systemExecutable, "#!/bin/sh\nOS_BIN_DIR=previous\n")
    suite:test(
        "Lua CLI installation publishes a validated standalone bundle and preserves the previous executable",
        function()
            installer:system()
            local listing = process:run("runtimeFiles", { active .. "/", "-type", "d", "-print0" })
            for path in listing:gmatch("[^%z]+") do
                local mode = assert(tonumber(process:run("fileMode", { path }), 16))
                assert(
                    mode & 0x1FF == tonumber(policy.runtimeDirectoryMode, 8),
                    "runtime directories must be traversable by desktop users"
                )
            end
            for _, path in ipairs(policy.runtimeDirectories) do
                local mode = assert(tonumber(process:run("fileMode", { policy.systemDataRoot .. "/" .. path }), 16))
                assert(mode & 0x1FF == tonumber(policy.runtimeDirectoryMode, 8))
            end
            assert(File.read(policy.systemExecutable .. ".bak"):find("OS_BIN_DIR=previous", 1, true))
            assert(
                File.read(active .. "/src/component/cli/application.lua")
                    == File.read(root .. "/src/component/cli/application.lua")
            )
            assert(File.read(active .. "/CHANGELOG.md") == File.read(root .. "/CHANGELOG.md"))
            local output = process:run(
                "environment",
                { "HOME=" .. home, "OS_LANG=en", policy.systemExecutable, "changelog", "1.0" }
            )
            assert(output:find("## Release v1.0", 1, true))
        end
    )
    suite:test("identical CLI installation reuses its immutable bundle", function()
        local first = process:run("readLink", { active })
        installer:system()
        assert(first == process:run("readLink", { active }))
    end)
    suite:test("user CLI publication preserves unrelated preferences and backs up its managed executable", function()
        local executable = paths:resolve("home", policy.userExecutable)
        write(executable, "OS_BIN_DIR=previous user\n")
        write(home .. "/.bashrc", "personal shell settings\n")
        installer:user()
        assert(process:run("readLink", { executable }):gsub("\n$", "") == policy.systemExecutable)
        assert(File.read(executable .. ".bak"):find("previous user", 1, true))
        assert(File.read(home .. "/.bashrc") == "personal shell settings\n")
        installer:user()
    end)
    suite:test("unmanaged user executables cannot be overwritten", function()
        local executable = paths:resolve("home", policy.userExecutable)
        assert(os.remove(executable))
        write(executable, "personal command\n")
        suite:reject(function()
            installer:user()
        end)
        assert(File.read(executable) == "personal command\n")
    end)
    suite:test("unmanaged system executables are rejected before runtime activation", function()
        local first = process:run("readLink", { active })
        assert(os.remove(policy.systemExecutable))
        write(policy.systemExecutable, "personal system command\n")
        suite:reject(function()
            installer:system()
        end)
        assert(File.read(policy.systemExecutable) == "personal system command\n")
        assert(first == process:run("readLink", { active }))
        assert(os.remove(policy.systemExecutable))
        process:run("symbolicLink", { active .. "/" .. policy.entrypoint, policy.systemExecutable })
    end)
    suite:test("invalid Lua cannot activate a new CLI runtime", function()
        local source = directory .. "/source"
        process:run("directory", { source })
        for _, name in ipairs({ "src", "data", "script" }) do
            process:run("copyTree", { root .. "/" .. name, source .. "/" .. name })
        end
        for _, relative in ipairs(policy.runtimeExtraFiles) do
            write(source .. "/" .. relative, File.read(root .. "/" .. relative))
        end
        write(source .. "/src/component/cli/application.lua", "this is not Lua !!!")
        local first = process:run("readLink", { active })
        local ok, failure = pcall(function()
            Installer.new(source, backend, policy, paths):system()
        end)
        assert(not ok and tostring(failure):find("validateLua", 1, true), tostring(failure))
        assert(first == process:run("readLink", { active }))
        assert(File.read(policy.systemExecutable):find("os%-lua"))
    end)
    process:run("removeDirectory", { directory })
end
