local Json = require("core.json")
local Menu = {}
Menu.__index = Menu

function Menu.new(process, format)
    return setmetatable({process=assert(process), format=assert(format)}, Menu)
end

function Menu:read(text)
    local hierarchy, entries, current = {}, Json.array({}), nil
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local slashes, title = line:match("^%s*(/+)([^/].-)%s*$")
        if slashes then
            for index = #hierarchy, #slashes, -1 do hierarchy[index] = nil end
            hierarchy[#hierarchy + 1] = title
            current = {title=table.concat(hierarchy, " / ")}
            entries[#entries + 1] = current
        elseif current then
            local key, value = line:match("^%s*(%a+):%s*(.-)%s*$")
            if key == "protocol" or key == "path" or key == "cmdline" then
                assert(current[key] == nil, "duplicate_field:" .. key)
                current[key] = value
            end
        end
    end
    local result = Json.array({})
    for _, entry in ipairs(entries) do
        if entry.path then
            assert(entry.protocol == "efi", "unsupported_protocol")
            local path, digest = entry.path:match("^boot%(%):(/[^#%s]+)#(%x+)$")
            if not path then path = entry.path:match("^boot%(%):(/[^#%s]+)$") end
            assert(path, "unsupported_efi_path")
            assert(not digest or #digest == self.format.digestLength, "invalid_digest")
            for segment in path:gmatch("[^/]+") do assert(segment ~= "..", "unsafe_efi_path") end
            result[#result + 1] = {title=entry.title, protocol=entry.protocol, path=path, blake2b=digest, cmdline=entry.cmdline or ""}
        end
    end
    return result
end

function Menu:verify(entries, esp)
    assert(#entries > 0, "no_efi_entries")
    local root = self.process:run("realpath", {esp}):gsub("\n$", "")
    for _, entry in ipairs(entries) do
        local path = self.process:run("realpath", {root .. entry.path}):gsub("\n$", "")
        assert(path:sub(1, #root + 1) == root .. "/", "efi_path_escapes_esp")
        local file = assert(io.open(path, "rb"))
        local ok, failure = pcall(function()
            local size = assert(file:seek("end"))
            assert(file:seek("set"))
            local header = file:read(self.format.headerSize)
            assert(header and #header == self.format.headerSize and header:sub(1, 2) == self.format.efiSignature, "invalid_efi_header")
            local offset = string.unpack("<I4", header, self.format.headerSize - 3)
            assert(offset >= self.format.headerSize and offset <= size - self.format.minimumPeSize, "invalid_pe_offset")
            assert(file:seek("set", offset))
            assert(file:read(#self.format.peSignature) == self.format.peSignature, "invalid_pe_signature")
        end)
        assert(file:close())
        assert(ok, failure)
        if entry.blake2b then
            local digest = self.process:run("digest", {path}):match("^(%x+)")
            assert(digest == entry.blake2b:lower(), "efi_integrity_mismatch")
        end
    end
    return entries
end

function Menu.quote(value)
    assert(type(value) == "string" and not value:find("[\r\n%z]"), "unsafe_grub_string")
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

function Menu:render(entries, uuid, policy)
    assert(uuid:match("^[%w-]+$"), "invalid_esp_uuid")
    assert(math.type(policy.timeout) == "integer" and policy.timeout >= self.format.timeoutMinimum and policy.timeout <= self.format.timeoutMaximum, "invalid_timeout")
    assert(math.type(policy.default) == "integer" and policy.default >= 0 and policy.default < #entries and policy.terminal == self.format.terminal, "invalid_menu_policy")
    assert(policy.colorNormal:match("^[a-z]+/[a-z]+$") and policy.colorHighlight:match("^[a-z]+/[a-z]+$"), "invalid_menu_color")
    local lines = {}
    for index, template in ipairs(self.format.preamble) do
        lines[#lines + 1] = index == 1 and template:format(policy.timeout) or index == 2 and template:format(policy.default) or template
    end
    lines[#lines + 1] = self.format.normal:format(Menu.quote(policy.colorNormal))
    lines[#lines + 1] = self.format.highlight:format(Menu.quote(policy.colorHighlight))
    for _, entry in ipairs(entries) do
        local title = entry.title:gsub("^[^/]+ / ", function() return policy.rootTitle .. " / " end, 1)
        lines[#lines + 1] = self.format.entry[1]:format(Menu.quote(title))
        lines[#lines + 1] = self.format.entry[2]:format(Menu.quote(uuid))
        lines[#lines + 1] = self.format.entry[3]:format(Menu.quote(entry.path), Menu.quote(entry.cmdline))
        lines[#lines + 1] = self.format.entry[4]
    end
    return table.concat(lines, "\n") .. "\n"
end

return Menu
