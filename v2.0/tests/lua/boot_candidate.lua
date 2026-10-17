local File = require("core.file")
local Json = require("core.json")
local Candidate = require("component.boot.candidate")

return function(suite, root, process)
    local directory = process:run("temporary", {"-d"}):gsub("\n$", "")
    local function write(path, content)
        process:run("directory", {assert(path:match("^(.*)/[^/]+$"))})
        local file = assert(io.open(path, "wb")); assert(file:write(content)); assert(file:close())
    end
    local policy = File.json(root .. "/data/component/boot/candidate.json")
    local boot = File.json(root .. "/data/component/boot/policy.json")
    policy.stateRoot = directory .. "/state"
    policy.manifest = policy.stateRoot .. "/state.json"
    boot.esp = directory .. "/esp"
    local destination = boot.esp .. "/EFI/" .. boot.candidateId .. "/" .. boot.candidateFile
    write(destination, "previous candidate")
    write(boot.esp .. "/" .. boot.grubConfiguration, "menuentry 'OS' {}\n")
    local backend = {builds=0, fail=false, run=function(self, name, args)
        if name == "identity" then return "0\n" end
        if name == "bootFirmware" then return "BootOrder: 0001,0000\n" end
        if name == "mountUuid" then return "1234-ABCD\n" end
        if name == "validateGrub" then
            local content = File.read(args[1])
            if args[1] ~= boot.esp .. "/" .. boot.grubConfiguration then
                assert(content:find("'1234-ABCD'", 1, true) and content:find("configfile ($root)/grub/grub.cfg", 1, true))
            end
            return ""
        end
        if name == "bootBuildStandalone" then
            self.builds = self.builds + 1
            assert(args[1]:find("normal", 1, true) and args[1]:find("tpm", 1, true))
            assert(args[3]:match("^boot/grub/grub.cfg="))
            if self.fail then error("fixture_build_failure") end
            write(assert(args[2]:match("^%-%-output=(.+)$")), "MZ fixture standalone")
            return ""
        end
        if name == "bootCheckGrubEFI" then assert(File.read(args[1]):match("^MZ")); return "" end
        return process:run(name, args)
    end}
    local candidate = Candidate.new(backend, policy, boot)
    write(policy.manifest, Json.encode({standalone=true, espUuid="1234-ABCD", digest="obsolete"}))
    suite:test("standalone GRUB embeds an explicit ESP lookup and preserves the previous candidate", function()
        local result = candidate:repair()
        assert(result.standalone and not result.hardwareBootVerified and result.espUuid == "1234-ABCD")
        assert(File.read(destination) == "MZ fixture standalone" and File.read(destination .. ".bak") == "previous candidate")
        local builds = backend.builds
        candidate:repair()
        assert(backend.builds == builds)
    end)
    suite:test("failed candidate generation cannot replace the validated EFI image", function()
        local before = File.read(destination)
        candidate.policy.modules[#candidate.policy.modules + 1] = "fixture"
        backend.fail = true
        suite:reject(function() candidate:repair() end)
        assert(File.read(destination) == before)
    end)
    process:run("removeDirectory", {directory})
end
