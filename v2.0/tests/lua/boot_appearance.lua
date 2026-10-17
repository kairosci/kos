local File = require("core.file")
local Json = require("core.json")
local Appearance = require("component.boot.appearance")

return function(suite, root, process)
    local directory = process:run("temporary", { "-d" }):gsub("\n$", "")
    local function write(path, content)
        process:run("directory", { assert(path:match("^(.*)/[^/]+$")) })
        local handle = assert(io.open(path, "wb"))
        assert(handle:write(content))
        assert(handle:close())
    end
    local policy = File.json(root .. "/data/component/boot/appearance.json")
    policy.esp = directory .. "/esp"
    policy.backupRoot = directory .. "/backups"
    policy.configuration = directory .. "/plymouthd.conf"
    policy.themeDefinition = directory .. "/text.plymouth"
    policy.state = policy.backupRoot .. "/state.json"
    policy.lastAttempt = policy.backupRoot .. "/attempt.json"
    policy.cmdline = directory .. "/cmdline"
    local image = "MZ" .. string.rep("\0", 58) .. string.pack("<I4", 64) .. "PE\0\0" .. string.rep("\0", 64)
    local primary = "/EFI/Linux/current.efi"
    local recovery = "/EFI/Linux/snapshot.efi"
    local command =
        "cryptdevice=PARTUUID=fixture:root root=/dev/mapper/root rootflags=subvol=@ resume=/dev/mapper/root resume_offset=99 lsm=apparmor quiet splash"
    write(policy.cmdline, command)
    write(policy.configuration, "[Daemon]\nTheme=omarchy\nShowDelay=2\n")
    write(policy.themeDefinition, "[Plymouth Theme]\nModuleName=text\n")
    local function inventory()
        local lines = {}
        for _, item in ipairs({
            { primary, command },
            { recovery, command:gsub("subvol=@", "subvol=/snapshots/one") },
            { recovery, command:gsub("subvol=@", "subvol=/snapshots/two") },
        }) do
            local digest = process:run("digest", { policy.esp .. item[1] }):match("^(%x+)")
            lines[#lines + 1] = "/"
                .. item[1]
                .. "\n protocol: efi\n path: boot():"
                .. item[1]
                .. "#"
                .. digest
                .. "\n cmdline: "
                .. item[2]
                .. "\n"
        end
        write(policy.esp .. "/" .. policy.inventory, table.concat(lines))
    end
    local function reset()
        write(policy.configuration, "[Daemon]\nTheme=omarchy\nShowDelay=2\n")
        write(policy.esp .. primary, image)
        write(policy.esp .. recovery, image .. "snapshot")
        inventory()
        local handle = io.open(policy.state, "rb")
        if handle then
            assert(handle:close())
            assert(os.remove(policy.state))
        end
    end
    local backend = {
        mode = "success",
        rebuilds = 0,
        extractions = 0,
        status = function(_, name, args)
            return process:status(name, args)
        end,
        run = function(self, name, args)
            if name == "identity" then return "0\n" end
            if name == "bootFirmware" then return "BootCurrent: 0001\nBootOrder: 0001,0000\n" end
            if name == "bootRegenerate" then
                self.rebuilds = self.rebuilds + 1
                write(policy.esp .. primary, image .. "text")
                inventory()
                if self.mode == "argument-loss" then
                    local path = policy.esp .. "/" .. policy.inventory
                    write(path, (File.read(path):gsub("resume_offset=99", "resume_offset=100", 1)))
                end
                if self.mode == "rebuild-failure" then error("fixture_rebuild_failed") end
                return ""
            end
            if name == "bootExtractInitrd" then
                self.extractions = self.extractions + 1
                assert(args[2] == policy.esp .. primary, "snapshot_must_not_be_rebuilt")
                write(assert(args[1]:match("^%.initrd=(.+)$")), "fixture initrd")
                return ""
            end
            if name == "bootListInitrd" then
                return self.mode == "retired-theme" and policy.retiredMembers[1] or policy.themeMember
            end
            return process:run(name, args)
        end,
    }
    local instance = Appearance.new(root, backend, policy)
    suite:test("boot argument comparison normalizes separators while preserving quoted values", function()
        assert(
            Appearance.arguments('root=/dev/mapper/root  parameter="two words" ')
                == Appearance.arguments('root=/dev/mapper/root parameter="two words"')
        )
        assert(Appearance.arguments('parameter="two  words"') ~= Appearance.arguments('parameter="two words"'))
        suite:reject(function()
            Appearance.arguments('parameter="unfinished')
        end)
    end)
    suite:test("boot appearance preserves encrypted arguments recovery images and theme preferences", function()
        reset()
        local originalMenu = File.read(policy.esp .. "/" .. policy.inventory)
        local status = instance:apply()
        assert(status.theme == "text" and status.verifiedImages == 1 and not status.hardwareBootVerified)
        assert(File.read(policy.configuration) == "[Daemon]\nTheme=text\nShowDelay=2\n")
        assert(File.read(policy.esp .. recovery) == image .. "snapshot")
        assert(File.read(status.backup .. "/esp" .. primary) == image)
        assert(File.read(status.backup .. "/esp/" .. policy.inventory) == originalMenu)
        assert(File.read(policy.esp .. "/" .. policy.inventory):find(command, 1, true))
        local before = backend.rebuilds
        instance:apply()
        assert(backend.rebuilds == before)
        local menuPath = policy.esp .. "/" .. policy.inventory
        local verifiedMenu = File.read(menuPath)
        write(menuPath, originalMenu)
        instance:apply()
        assert(File.read(menuPath) == verifiedMenu and backend.rebuilds == before)
        write(policy.esp .. primary, image .. "unverified drift")
        suite:reject(function()
            instance:apply()
        end)
        assert(File.read(menuPath) == verifiedMenu)
    end)
    suite:test("a failed initrd rebuild restores the previous complete boot payload", function()
        reset()
        backend.mode = "rebuild-failure"
        local before = File.read(policy.esp .. "/" .. policy.inventory)
        suite:reject(function()
            instance:apply()
        end)
        assert(File.read(policy.configuration):find("Theme=omarchy", 1, true))
        assert(File.read(policy.esp .. primary) == image and File.read(policy.esp .. "/" .. policy.inventory) == before)
    end)
    suite:test("changed encryption or resume arguments prevent activation and restore recovery", function()
        reset()
        backend.mode = "argument-loss"
        local before = File.read(policy.esp .. "/" .. policy.inventory)
        suite:reject(function()
            instance:apply()
        end)
        assert(File.read(policy.esp .. "/" .. policy.inventory) == before)
        assert(File.read(policy.esp .. primary) == image)
    end)
    suite:test("an image still containing stock unlock artwork cannot be activated", function()
        reset()
        backend.mode = "retired-theme"
        suite:reject(function()
            instance:apply()
        end)
        assert(File.read(policy.esp .. primary) == image)
        assert(File.read(policy.configuration):find("Theme=omarchy", 1, true))
    end)
    process:run("removeDirectory", { directory })
end
