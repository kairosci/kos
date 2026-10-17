local Trial = require("component.boot.trial")
local File = require("core.file")

return function(suite, root)
    local policy = File.json(root .. "/data/component/boot/policy.json")
    local original = "BootOrder: 0001,0009\nBoot0000* OS GRUB trial\tHD(1,GPT,fixture)/\\EFI\\OS-GRUB\\grubx64.efi\nBoot0001* Limine\tHD(1,GPT,fixture)/\\EFI\\limine\\limine_x64.efi\n"
    local backend = {firmware=original, nextEntry=nil, drift=false, run=function(self, name, args)
        if name == "identity" then return "0\n" end
        if name == "bootFirmwareNext" then self.nextEntry = args[1]; return "" end
        assert(name == "bootFirmware")
        local firmware = self.firmware
        if self.drift and self.nextEntry then firmware = firmware:gsub("BootOrder: 0001,0009", "BootOrder: 0009,0001") end
        return firmware .. (self.nextEntry and "BootNext: " .. self.nextEntry .. "\n" or "")
    end}
    local trial = Trial.new(backend, policy)
    suite:test("the exact firmware candidate is selected for one boot without changing permanent order", function()
        assert(trial:select() == "0000" and backend.nextEntry == "0000" and backend.firmware == original)
    end)
    suite:test("similar labels and different EFI paths cannot select another loader", function()
        backend.nextEntry = nil
        backend.firmware = original:gsub("OS GRUB trial", "OS GRUB trial other")
        suite:reject(function() trial:select() end); assert(not backend.nextEntry)
        backend.firmware = original:gsub("OS%-GRUB", "OTHER")
        suite:reject(function() trial:select() end); assert(not backend.nextEntry)
    end)
    suite:test("ambiguous firmware candidates and path suffixes are rejected before BootNext", function()
        backend.firmware = original .. "Boot0002* OS GRUB trial\tHD(1,GPT,fixture)/\\EFI\\OS-GRUB\\grubx64.efi\n"
        suite:reject(function() trial:select() end); assert(not backend.nextEntry)
        backend.firmware = original:gsub("grubx64.efi", "grubx64.efiOTHER")
        suite:reject(function() trial:select() end); assert(not backend.nextEntry)
    end)
    suite:test("firmware order drift after a selection is detected", function()
        backend.firmware = original; backend.drift = true
        suite:reject(function() trial:select() end)
    end)
    suite:test("duplicate and malformed firmware order records are rejected", function()
        suite:reject(function() Trial.order("BootOrder: 0001,\n") end)
        suite:reject(function() Trial.order("BootOrder: 0001\nBootOrder: 0002\n") end)
        suite:reject(function() Trial.order("BootOrder: 0001,0001\n") end)
    end)
end
