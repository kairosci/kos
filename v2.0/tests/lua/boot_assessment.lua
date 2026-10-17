local File = require("core.file")
local Json = require("core.json")
local Assessment = require("component.boot.assessment")

return function(suite, root, process)
    local directory = process:run("temporary", { "-d" }):gsub("\n$", "")
    local function write(path, content)
        process:run("directory", { assert(path:match("^(.*)/[^/]+$")) })
        local handle = assert(io.open(path, "wb"))
        assert(handle:write(content))
        assert(handle:close())
    end
    local policy = File.json(root .. "/data/component/boot/assessment.json")
    local boot = File.json(root .. "/data/component/boot/policy.json")
    policy.destination = directory .. "/assessment"
    policy.cmdline = directory .. "/cmdline"
    policy.configuration = Json.array({ directory .. "/mkinitcpio.conf", directory .. "/missing.conf" })
    policy.presets = directory .. "/presets"
    boot.esp = directory .. "/esp"
    local binary = "MZ" .. string.rep("\0", 58) .. string.pack("<I4", 64) .. "PE\0\0" .. string.rep("\0", 64)
    local image = boot.esp .. "/EFI/Linux/current.efi"
    write(image, binary)
    local digest = process:run("digest", { image }):match("^(%x+)")
    write(
        boot.esp .. "/" .. policy.inventory,
        "/OS\n protocol: efi\n path: boot():/EFI/Linux/current.efi#"
            .. digest
            .. "\n cmdline: cryptdevice=fixture rootflags=subvol=@ resume_offset=99\n"
    )
    write(policy.cmdline, "cryptdevice=fixture rootflags=subvol=@ resume_offset=99\n")
    write(policy.configuration[1], "HOOKS=(base encrypt filesystems)\n")
    write(policy.presets .. "/linux.preset", "native preset\n")
    local backend = {
        invalid = false,
        status = function(_, name, args)
            return process:status(name, args)
        end,
        run = function(self, name, args)
            if name == "identity" then return "0\n" end
            if name == "bootFirmware" then return "BootOrder: 0001,0000\n" end
            if name == "bootFileInventory" then return "EFI/Linux/current.efi\t132\n" end
            if name == "bootDevices" or name == "bootEspMount" or name == "bootRootMount" then
                return self.invalid and "invalid JSON" or "{}"
            end
            if name == "bootPresets" then return policy.presets .. "/linux.preset\0" end
            return process:run(name, args)
        end,
    }
    local assessment =
        Assessment.new(root, backend, policy, boot, File.json(root .. "/data/component/boot/render.json"))
    suite:test(
        "boot inventory validates images before privately publishing observations and recovery policy",
        function()
            local result = assessment:record()
            assert(result.entries == 1 and not result.trialBootVerified)
            assert(File.read(policy.destination .. "/current-cmdline.txt") == File.read(policy.cmdline))
            assert(File.read(policy.destination .. "/linux.preset") == "native preset\n")
            assert(
                File.json(policy.destination .. "/verified-menu.json").entries[1].cmdline
                    :find("resume_offset=99", 1, true)
            )
            local mode = tonumber(process:run("fileMode", { policy.destination .. "/firmware.txt" }), 16)
            assert(mode & 0x1FF == tonumber("600", 8))
            local before = File.read(policy.destination .. "/verified-menu.json")
            assessment:record()
            assert(File.read(policy.destination .. "/verified-menu.json") == before)
        end
    )
    suite:test("invalid observations and corrupted images cannot replace the accepted inventory", function()
        local before = File.read(policy.destination .. "/verified-menu.json")
        backend.invalid = true
        suite:reject(function()
            assessment:record()
        end)
        assert(File.read(policy.destination .. "/verified-menu.json") == before)
        backend.invalid = false
        write(image, binary .. "changed")
        suite:reject(function()
            assessment:record()
        end)
        assert(File.read(policy.destination .. "/verified-menu.json") == before)
    end)
    process:run("removeDirectory", { directory })
end
