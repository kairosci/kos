local Publisher = {}
Publisher.__index = Publisher

function Publisher.new(process)
    return setmetatable({ process = assert(process) }, Publisher)
end

function Publisher:inspect(destination)
    assert(self.process:status("isLink", { destination }) == 1, "redirected_publication_path")
    local exists = self.process:status("pathExists", { destination })
    assert(exists == 0 or exists == 1, "publication_probe_failed")
    if exists == 1 then return nil end
    local mode = assert(tonumber(self.process:run("fileMode", { destination }), 16))
    assert(mode & 0xF000 == 0x8000, "nonregular_publication_path")
    local file = assert(io.open(destination, "rb"))
    local content, readFailure = file:read("a")
    assert(file:close())
    assert(content, readFailure)
    return content, mode
end

function Publisher:publish(destination, content, mode, validator, preserve)
    local parent = assert(destination:match("^(.*)/[^/]+$"), "invalid_destination")
    self.process:run("directory", { parent })
    local previous = self:inspect(destination)
    local old = previous ~= nil
    if old then
        if previous == content then
            self.process:run("permissions", { mode, destination })
            local backup = self:inspect(destination .. ".bak")
            if backup ~= nil then self.process:run("permissions", { mode, destination .. ".bak" }) end
            return false
        end
    end
    local temporary = self.process:run("temporary", { destination .. ".tmp.XXXXXX" }):gsub("\n$", "")
    local ok, failure = pcall(function()
        local handle = assert(io.open(temporary, "wb"))
        local written, write_error = handle:write(content)
        local closed, close_error = handle:close()
        assert(written and closed, write_error or close_error)
        self.process:run("permissions", { mode, temporary })
        if validator then validator(temporary) end
        if old and preserve ~= false then self:publish(destination .. ".bak", previous, mode, nil, false) end
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
