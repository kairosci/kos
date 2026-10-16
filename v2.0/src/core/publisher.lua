local Publisher = {}
Publisher.__index = Publisher

function Publisher.new(process)
    return setmetatable({process=assert(process)}, Publisher)
end

function Publisher:publish(destination, content, mode, validator, preserve)
    local parent = assert(destination:match("^(.*)/[^/]+$"), "invalid_destination")
    self.process:run("directory", {parent})
    local old, open_error, open_code = io.open(destination, "rb")
    assert(old or open_code == 2, open_error)
    local previous
    if old then
        previous = assert(old:read("a")); assert(old:close())
        local permissions = assert(tonumber(self.process:run("fileMode", {destination}), 16))
        assert(permissions & 0xF000 == 0x8000, "nonregular_destination")
        if previous == content then
            self.process:run("permissions", {mode, destination})
            local backup = io.open(destination .. ".bak", "rb")
            if backup then
                assert(backup:close())
                local backup_mode = assert(tonumber(self.process:run("fileMode", {destination .. ".bak"}), 16))
                assert(backup_mode & 0xF000 == 0x8000, "nonregular_backup")
                self.process:run("permissions", {mode, destination .. ".bak"})
            end
            return false
        end
    end
    local temporary = self.process:run("temporary", {destination .. ".tmp.XXXXXX"}):gsub("\n$", "")
    local ok, failure = pcall(function()
        local handle = assert(io.open(temporary, "wb"))
        local written, write_error = handle:write(content)
        local closed, close_error = handle:close()
        assert(written and closed, write_error or close_error)
        self.process:run("permissions", {mode, temporary})
        if validator then validator(temporary) end
        if old and preserve ~= false then
            self:publish(destination .. ".bak", previous, mode, nil, false)
        end
        assert(os.rename(temporary, destination))
    end)
    if not ok then
        local removed, remove_error = os.remove(temporary)
        assert(removed, remove_error)
        error(failure)
    end
    return true
end

return Publisher
