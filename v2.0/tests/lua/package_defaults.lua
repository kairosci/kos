local File = require("core.file")
local Installer = require("component.package.defaults")

return function(suite, root)
    local policy = File.json(root .. "/data/component/package/defaults.json")

    suite:test("default package policy is valid and separates optional packages", function()
        local names = {}
        for _, group in ipairs(policy.groups) do
            assert((group.source == "official" or group.source == "aur") and type(group.required) == "boolean")
            for _, package in ipairs(group.packages) do
                assert(package:match("^[a-z0-9][a-z0-9+_.-]*$"))
                assert(not names[package], "duplicate_default_package")
                names[package] = true
            end
        end
        assert(names["brave-origin-bin"] and names.nautilus and names.kitty and names.podman)
        assert(not names.chromium and not names.thunar)
    end)

    local function fixture(missing, failure)
        local calls = {}
        local process = {
            run = function(_, name, arguments)
                calls[#calls + 1] = { name = name, arguments = arguments }
                if name == "identity" then return "0\n" end
                if name == "pacmanInstall" and failure then error("package_install_failed") end
                return ""
            end,
            capture = function(_, name, arguments)
                assert(name == "pacmanInstalled")
                if missing[arguments[1]] then return "", 1 end
                return arguments[1] .. "\n", 0
            end,
        }
        local aur = { new = function(_, _, user)
            assert(user == "fixture")
            return { install = function(_, package) calls[#calls + 1] = { name = "aur", package = package } end }
        end }
        local catalog = { text = function(_, _, package) return "failed " .. package end }
        return process, aur, catalog, calls
    end

    suite:test("default installer batches missing official packages and installs missing AUR packages", function()
        local process, aur, catalog, calls = fixture({ zed = true, ["brave-origin-bin"] = true })
        local count = Installer.new(process, policy, aur, {}, catalog):install("fixture")
        assert(count == 2)
        local official, aurCount = 0, 0
        for _, call in ipairs(calls) do
            if call.name == "pacmanInstall" then
                official = official + 1
                assert(table.concat(call.arguments, ",") == "zed")
            elseif call.name == "aur" then
                aurCount = aurCount + 1
                assert(call.package == "brave-origin-bin")
            end
        end
        assert(official == 1 and aurCount == 1)
    end)

    suite:test("default installer rejects invalid identity and package query errors", function()
        local process, aur, catalog = fixture({})
        process.run = function(_, name)
            if name == "identity" then return "1000\n" end
            error("unexpected_process")
        end
        suite:reject(function() Installer.new(process, policy, aur, {}, catalog):install("fixture") end)
        process, aur, catalog = fixture({})
        process.capture = function() return "", 42 end
        suite:reject(function() Installer.new(process, policy, aur, {}, catalog):install("fixture") end)
    end)
end
