local File = require("core.file")
local Publisher = require("core.publisher")
local Authentication = {}
Authentication.__index = Authentication

local function fields(line)
    local result = {}
    for value in line:gmatch("%S+") do result[#result + 1] = value end
    return result
end

local function is_faillock_override(token)
    return token:match("^deny=") ~= nil
        or token:match("^unlock_time=") ~= nil
        or token:match("^conf=") ~= nil
end

function Authentication.transform(content, qualityLine)
    assert(type(content) == "string" and type(qualityLine) == "string", "invalid_pam_input")
    assert(qualityLine == "password requisite pam_pwquality.so retry=3 enforce_for_root", "invalid_pam_quality_policy")
    local output, hasFaillock, hasUnixPassword, qualityInserted = {}, false, false, false
    local finalNewline = content:sub(-1) == "\n"
    for line in (content .. (finalNewline and "" or "\n")):gmatch("(.-)\n") do
        if line:match("^%s*#") then
            output[#output + 1] = line
        else
            local tokens = fields(line)
            local directive = tokens[1] or ""
            local isPassword = directive:match("^-?password$") ~= nil
            local isAuth = directive:match("^-?auth$") ~= nil
            if line:find("pam_pwquality%.so") and isPassword then
                -- Replaced by the single canonical quality line below.
            else
                if isPassword and not qualityInserted then
                    output[#output + 1] = qualityLine
                    qualityInserted = true
                end
                local hasFaillockLine = line:find("pam_faillock%.so") ~= nil
                if hasFaillockLine then hasFaillock = true end
                if line:find("pam_unix%.so") and (isPassword or isAuth) then
                    local cleaned = {}
                    for _, token in ipairs(tokens) do
                        if token ~= "nullok" and not (hasFaillockLine and is_faillock_override(token)) then
                            cleaned[#cleaned + 1] = token
                        end
                    end
                    if isPassword then
                        hasUnixPassword = true
                        local found = false
                        for _, token in ipairs(cleaned) do if token == "use_authtok" then found = true end end
                        if not found then cleaned[#cleaned + 1] = "use_authtok" end
                    end
                    output[#output + 1] = table.concat(cleaned, " ")
                elseif hasFaillockLine then
                    local cleaned = {}
                    for _, token in ipairs(tokens) do
                        if not is_faillock_override(token) then cleaned[#cleaned + 1] = token end
                    end
                    output[#output + 1] = table.concat(cleaned, " ")
                else
                    output[#output + 1] = line
                end
            end
        end
    end
    assert(hasFaillock and hasUnixPassword, "unsupported_pam_stack")
    local transformed = table.concat(output, "\n")
    if finalNewline then transformed = transformed .. "\n" end
    return transformed
end

function Authentication.new(process, policy, catalog, adapters)
    adapters = adapters or {}
    return setmetatable({
        process = assert(process),
        policy = assert(policy),
        catalog = catalog,
        publisher = adapters.publisher or Publisher.new(process),
        pam_adapter = adapters.pam_adapter,
        read_file = adapters.read_file or File.read,
    }, Authentication)
end

function Authentication:prepare_pam()
    local process, path = self.process, self.policy.pamPath
    assert(path:sub(1, 1) == "/", "absolute_pam_path_required")
    assert(process:status("isLink", { path }) == 1, "redirected_pam_path")
    local source = self.read_file(path)
    local transformed = Authentication.transform(source, self.policy.pamQualityLine)
    return source, transformed
end

function Authentication:reconcile_pam(source, transformed)
    local process, path = self.process, self.policy.pamPath
    assert(process:status("isLink", { path }) == 1, "redirected_pam_path")
    source = source or self.read_file(path)
    transformed = transformed or Authentication.transform(source, self.policy.pamQualityLine)
    assert(self.read_file(path) == source, "pam_stack_changed_during_reconciliation")
    if transformed == source then return false end
    local directory = assert(path:match("^(.*)/[^/]+$"))
    local temporary = process:run("temporary", { directory .. "/.os-pam.XXXXXX" }):gsub("\n$", "")
    local ok, failure = pcall(function()
        local handle = assert(io.open(temporary, "wb"))
        local written, writeError = handle:write(transformed)
        local closed, closeError = handle:close()
        assert(written and closed, writeError or closeError)
        process:run("permissionsReference", { path, temporary })
        process:run("ownershipReference", { path, temporary })
        local backup = path .. ".os-backup"
        assert(process:status("isLink", { backup }) == 1, "redirected_pam_backup")
        local backupExists = process:status("pathExists", { backup })
        assert(backupExists == 0 or backupExists == 1, "pam_backup_probe_failed")
        if backupExists == 1 then process:run("copyPreserve", { path, backup }) end
        process:run("move", { temporary, path })
    end)
    if not ok then
        local removed, removeError = os.remove(temporary)
        assert(removed, removeError)
        error(failure)
    end
    return true
end

function Authentication:apply()
    local process, policy = self.process, self.policy
    assert(process:run("identity"):match("^0%s*$"), "root_required")
    local pamSource, pamTarget = self:prepare_pam()
    assert(policy.package:match("^[a-z0-9][a-z0-9+_.-]*$"), "invalid_auth_package")
    local installed, status = process:capture("pacmanInstalled", { policy.package })
    assert(status == 0 or status == 1, "pacman_query_failed")
    if status == 0 then
        assert(installed:gsub("%s+$", "") == policy.package, "pacman_package_mismatch")
    else
        process:run("pacmanInstall", { policy.package })
    end
    for _, file in ipairs(policy.files) do self.publisher:publish(file.path, file.content, file.mode) end
    if self.pam_adapter then
        self.pam_adapter(policy.pamPath, policy.pamQualityLine, pamSource, pamTarget)
    else
        self:reconcile_pam(pamSource, pamTarget)
    end
end

function Authentication:verify()
    local installed, packageStatus = self.process:capture("pacmanInstalled", { self.policy.package })
    if packageStatus ~= 0 or installed:gsub("%s+$", "") ~= self.policy.package then return false end
    for _, file in ipairs(self.policy.files) do
        local content, status = self.process:capture("securityFilePrivileged", { file.path })
        if status ~= 0 or content ~= file.content then return false end
    end
    local pam, status = self.process:capture("securityFilePrivileged", { self.policy.pamPath })
    if status ~= 0 then return false end
    local ok, transformed = pcall(Authentication.transform, pam, self.policy.pamQualityLine)
    return ok and transformed == pam
end

return Authentication
