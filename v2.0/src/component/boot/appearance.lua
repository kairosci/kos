local File = require("core.file")
local Json = require("core.json")
local Ini = require("core.ini")
local Publisher = require("core.publisher")
local Menu = require("component.boot.menu")
local Appearance = {}
Appearance.__index = Appearance

function Appearance.new(root, process, policy)
    return setmetatable({root=root, process=process, policy=policy, publisher=Publisher.new(process)}, Appearance)
end

function Appearance.arguments(value)
    local tokens, current, quote, escaped = {}, {}, nil, false
    for char in value:gmatch(".") do
        if escaped then current[#current + 1] = char; escaped = false
        elseif char == "\\" then current[#current + 1] = char; escaped = true
        elseif quote then
            current[#current + 1] = char
            if char == quote then quote = nil end
        elseif char == "\"" or char == "'" then quote = char; current[#current + 1] = char
        elseif char:match("%s") then
            if #current > 0 then tokens[#tokens + 1] = table.concat(current); current = {} end
        else current[#current + 1] = char end
    end
    assert(not quote and not escaped, "invalid_boot_arguments")
    if #current > 0 then tokens[#tokens + 1] = table.concat(current) end
    return table.concat(tokens, "\0")
end

function Appearance:entries()
    local policy = self.policy
    local parser = Menu.new(self.process, File.json(self.root .. "/" .. policy.menu))
    return parser:verify(parser:read(File.read(policy.esp .. "/" .. policy.inventory)), policy.esp)
end

function Appearance:reconcile_inventory()
    local policy = self.policy
    local handle = io.open(policy.state, "rb")
    if not handle then return end
    assert(handle:close())
    local state = File.json(policy.state)
    local accepted = File.json(policy.lastAttempt).after
    local parser = Menu.new(self.process, File.json(self.root .. "/" .. policy.menu))
    local path = policy.esp .. "/" .. policy.inventory
    local content = File.read(path)
    local entries = parser:read(content)
    local known = {}
    for _, entry in ipairs(accepted) do known[entry.path .. "\0" .. Appearance.arguments(entry.cmdline)] = true end
    local changed = false
    for _, entry in ipairs(entries) do
        if entry.blake2b then
            local actual = self.process:run("digest", {policy.esp .. entry.path}):match("^(%x+)")
            if actual ~= entry.blake2b then
                assert(known[entry.path .. "\0" .. Appearance.arguments(entry.cmdline)] and state.images[entry.path] == actual, "unverified_boot_image_drift")
                local literal = "boot():" .. entry.path .. "#" .. entry.blake2b
                local pattern = literal:gsub("([^%w])", "%%%1")
                content = content:gsub(pattern, function() return "boot():" .. entry.path .. "#" .. actual end)
                changed = true
            end
        end
    end
    if changed then
        parser:verify(parser:read(content), policy.esp)
        self.publisher:publish(path, content, policy.configMode, function(candidate) parser:verify(parser:read(File.read(candidate)), policy.esp) end)
    end
end

function Appearance:fingerprint(entries)
    local result = {}
    for _, entry in ipairs(entries) do
        result[entry.path] = self.process:run("digest", {self.policy.esp .. entry.path}):match("^(%x+)")
    end
    return result
end

function Appearance:verify_payload(entries, stage)
    local current = File.read(self.policy.cmdline)
    local root = assert(current:match(self.policy.rootArgument .. "=([^%s]+)"), "boot_root_argument_missing")
    local verified = 0
    for _, entry in ipairs(entries) do
        if entry.cmdline:match(self.policy.rootArgument .. "=([^%s]+)") == root then
            local initrd = stage .. "/initrd"
            self.process:run("bootExtractInitrd", {".initrd=" .. initrd, self.policy.esp .. entry.path})
            local listing = self.process:run("bootListInitrd", {initrd})
            assert(listing:find(self.policy.themeMember, 1, true), "boot_theme_missing_from_initrd")
            for _, retired in ipairs(self.policy.retiredMembers) do
                assert(not listing:find(retired, 1, true), "retired_boot_theme_in_initrd")
            end
            assert(os.remove(initrd))
            verified = verified + 1
        end
    end
    assert(verified > 0, "no_primary_boot_images_verified")
    return verified
end

function Appearance:apply()
    assert(self.process:run("identity"):match("^0%s*$"), "root_required")
    local policy = self.policy
    assert(File.read(policy.themeDefinition):find("ModuleName=text", 1, true), "invalid_boot_theme")
    self:reconcile_inventory()
    local original = File.read(policy.configuration)
    local content = Ini.merge("[Daemon]\nTheme=" .. policy.theme .. "\n", original)
    local before = self:entries()
    local fingerprint = self:fingerprint(before)
    local state = io.open(policy.state, "rb")
    if state then
        local data = Json.decode(assert(state:read("a"))); assert(state:close())
        if content == original and Json.encode(data.images) == Json.encode(fingerprint) then return data end
    end
    self.process:run("directory", {policy.backupRoot})
    self.process:run("permissions", {"700", policy.backupRoot})
    local backup = self.process:run("temporary", {"-d", policy.backupRoot .. "/backup.XXXXXXXX"}):gsub("\n$", "")
    self.process:run("bootCopy", {policy.esp .. "/.", backup .. "/esp"})
    for path, digest in pairs(fingerprint) do
        assert(self.process:run("digest", {backup .. "/esp" .. path}):match("^(%x+)") == digest, "boot_backup_integrity_failure")
    end
    self.publisher:publish(backup .. "/plymouthd.conf", original, policy.mode)
    local firmware = self.process:run("bootFirmware")
    local order = assert(firmware:match("BootOrder:%s*([^\r\n]+)"), "missing_firmware_order")
    local ok, result = pcall(function()
        self.publisher:publish(policy.configuration, content, policy.configMode)
        self.process:run(policy.regenerator)
        local after = self:entries()
        self.publisher:publish(policy.lastAttempt, Json.encode({before=before, after=after}), policy.mode)
        assert(#after >= #before, "boot_entry_count_changed")
        local expected = {}
        for _, entry in ipairs(before) do expected[entry.path .. "\0" .. Appearance.arguments(entry.cmdline)] = true end
        for _, entry in ipairs(after) do expected[entry.path .. "\0" .. Appearance.arguments(entry.cmdline)] = nil end
        assert(next(expected) == nil, "boot_arguments_changed")
        assert(self.process:run("bootFirmware"):match("BootOrder:%s*([^\r\n]+)") == order, "firmware_order_changed")
        local verified = self:verify_payload(after, backup)
        local status = {theme=policy.theme, images=self:fingerprint(after), verifiedImages=verified, backup=backup, hardwareBootVerified=false}
        self.publisher:publish(policy.state, Json.encode(status), policy.mode)
        return status
    end)
    if not ok then
        self.process:run("bootCopy", {backup .. "/esp/.", policy.esp})
        self.publisher:publish(policy.configuration, original, policy.configMode)
        if self.process:run("bootFirmware"):match("BootOrder:%s*([^\r\n]+)") ~= order then
            self.process:run("bootFirmwareRestore", {order})
            assert(self.process:run("bootFirmware"):match("BootOrder:%s*([^\r\n]+)") == order, "firmware_order_restore_failed")
        end
        error(result)
    end
    return result
end

return Appearance
