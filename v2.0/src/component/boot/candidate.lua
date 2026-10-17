local File = require("core.file")
local Json = require("core.json")
local Publisher = require("core.publisher")
local Menu = require("component.boot.menu")
local Candidate = {}
Candidate.__index = Candidate

function Candidate.new(process, policy, boot)
    return setmetatable(
        { process = process, policy = policy, boot = boot, publisher = Publisher.new(process) },
        Candidate
    )
end

function Candidate:repair()
    local process, policy, boot = self.process, self.policy, self.boot
    assert(process:run("identity"):match("^0%s*$"), "root_required")
    local firmware = process:run("bootFirmware")
    local order = assert(firmware:match("BootOrder:%s*([^\r\n]+)"), "missing_firmware_order")
    local configuration = boot.esp .. "/" .. boot.grubConfiguration
    process:run("validateGrub", { configuration })
    local uuid = process:run("mountUuid", { boot.esp }):gsub("\n$", "")
    assert(uuid:match("^[%x-]+$"), "invalid_esp_uuid")
    local destination = boot.esp .. "/EFI/" .. boot.candidateId .. "/" .. boot.candidateFile
    local previous = io.open(policy.manifest, "rb")
    if previous then
        local status = Json.decode(assert(previous:read("a")))
        assert(previous:close())
        if
            status.standalone
            and status.espUuid == uuid
            and type(status.policy) == "table"
            and Json.encode(status.policy) == Json.encode(policy)
            and status.digest == process:run("digest", { destination }):match("^(%x+)")
        then
            process:run("bootCheckGrubEFI", { destination })
            return status
        end
    end
    process:run("directory", { policy.stateRoot })
    process:run("permissions", { "700", policy.stateRoot })
    local stage = process:run("temporary", { "-d", policy.stateRoot .. "/stage.XXXXXXXX" }):gsub("\n$", "")
    local ok, result = pcall(function()
        local embedded = stage .. "/grub.cfg"
        local source = stage .. "/" .. policy.output
        self.publisher:publish(embedded, policy.embeddedFormat:format(Menu.quote(uuid)), policy.fileMode)
        process:run("validateGrub", { embedded })
        process:run("bootBuildStandalone", {
            "--modules=" .. table.concat(policy.modules, " "),
            "--output=" .. source,
            policy.embeddedEntry .. "=" .. embedded,
        })
        process:run("bootCheckGrubEFI", { source })
        self.publisher:publish(destination, File.read(source), policy.fileMode, function(path)
            process:run("bootCheckGrubEFI", { path })
        end)
        assert(process:run("bootFirmware"):match("BootOrder:%s*([^\r\n]+)") == order, "firmware_order_changed")
        local status = {
            image = destination,
            digest = process:run("digest", { destination }):match("^(%x+)"),
            standalone = true,
            espUuid = uuid,
            policy = policy,
            hardwareBootVerified = false,
        }
        self.publisher:publish(policy.manifest, Json.encode(status), "600")
        return status
    end)
    process:run("removeDirectory", { stage })
    assert(ok, result)
    return result
end

return Candidate
