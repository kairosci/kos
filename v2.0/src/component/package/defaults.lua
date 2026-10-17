local Installer = {}
Installer.__index = Installer

function Installer.new(process, policy, aur, aurPolicy, catalog)
    return setmetatable({ process = assert(process), policy = assert(policy), aur = assert(aur), aurPolicy = assert(aurPolicy), catalog = catalog }, Installer)
end

local function validate_package(package)
    assert(type(package) == "string" and package:match("^[a-z0-9][a-z0-9+_.-]*$"), "invalid_default_package")
end

function Installer:install(user)
    assert(self.process:run("identity"):match("^0%s*$"), "root_required")
    assert(type(user) == "string" and user:match("^[A-Za-z0-9._-]+$"), "invalid_build_user")
    local installedCount = 0
    for _, group in ipairs(self.policy.groups) do
        assert(group.source == "official" or group.source == "aur", "invalid_package_source")
        assert(type(group.required) == "boolean" and type(group.packages) == "table", "invalid_package_group")
        local missing = {}
        for _, package in ipairs(group.packages) do
            validate_package(package)
            local output, status = self.process:capture("pacmanInstalled", { package })
            assert(status == 0 or status == 1, "pacman_query_failed")
            if status == 0 then
                assert(output:gsub("[\r\n]+$", "") == package, "invalid_pacman_query")
            else
                missing[#missing + 1] = package
            end
        end
        local ok, failure = pcall(function()
            if group.source == "official" then
                if #missing > 0 then self.process:run("pacmanInstall", missing) end
            else
                local aur = self.aur.new(self.process, self.aurPolicy, user)
                for _, package in ipairs(missing) do aur:install(package) end
            end
        end)
        if not ok then
            if group.required then error(failure) end
            if self.catalog then
                for _, package in ipairs(missing) do
                    io.stderr:write(self.catalog:text("defaults.app_failed", package), "\n")
                end
            end
        else
            installedCount = installedCount + #missing
        end
    end
    return installedCount
end

return Installer
