local Trial = {}
Trial.__index = Trial

function Trial.new(process, policy)
    return setmetatable({process=process, policy=policy}, Trial)
end

function Trial.order(firmware)
    local order
    for line in firmware:gmatch("[^\r\n]+") do
        local value = line:match("^BootOrder:%s*(.-)%s*$")
        if value then assert(not order, "duplicate_firmware_order"); order = value end
    end
    assert(order and order ~= "", "missing_firmware_order")
    local seen, count = {}, 0
    for id in (order .. ","):gmatch("([^,]*),") do
        assert(id:match("^%x%x%x%x$") and not seen[id:lower()], "invalid_firmware_order")
        seen[id:lower()] = true; count = count + 1
    end
    assert(count > 0, "empty_firmware_order")
    return order
end

function Trial:select()
    assert(self.process:run("identity"):match("^0%s*$"), "root_required")
    local policy = self.policy
    assert(policy.candidateId:match("^[%a][%a-]*$") and policy.candidateFile:match("^[%w_.-]+$"), "invalid_firmware_candidate")
    local firmware = self.process:run("bootFirmware")
    local order = Trial.order(firmware)
    local loader = "\\EFI\\" .. policy.candidateId .. "\\" .. policy.candidateFile
    local selected
    for line in firmware:gmatch("[^\r\n]+") do
        local id, label, path = line:match("^Boot(%x%x%x%x)%*?%s+(.-)\t(.*)$")
        if id and label == policy.candidateLabel and path:find(loader, 1, true) then
            local tail = path:sub(assert(path:find(loader, 1, true)) + #loader)
            assert(tail == "" or tail:match("^%s"), "ambiguous_firmware_path")
            assert(not selected, "ambiguous_firmware_candidates")
            selected = id
        end
    end
    assert(selected, "firmware_candidate_missing")
    self.process:run("bootFirmwareNext", {selected})
    local after = self.process:run("bootFirmware")
    assert(Trial.order(after) == order, "firmware_order_changed")
    local nextEntry, occurrences = nil, 0
    for line in after:gmatch("[^\r\n]+") do
        local id = line:match("^BootNext:%s*(%x%x%x%x)%s*$")
        if id then nextEntry = id; occurrences = occurrences + 1 end
    end
    assert(occurrences == 1 and nextEntry == selected, "firmware_selection_failed")
    return selected
end

return Trial
