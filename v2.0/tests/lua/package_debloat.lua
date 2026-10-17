local File = require("core.file")
local Debloat = require("component.package.debloat")

return function(suite, root)
    local sourcePolicy = File.json(root .. "/data/component/package/debloat.json")
    local function fixture(installed, configuration, pinExists, link)
        local path = os.tmpname()
        local handle = assert(io.open(path, "wb"))
        assert(handle:write(configuration or "[options]\nIgnorePkg = linux\n# IgnorePkg = documented\nColor\n"))
        assert(handle:close())
        local policy = {
            removePackages = { "remove-me", "keep-me" },
            pacmanConfiguration = path,
            obsoletePinList = path .. ".pins",
        }
        if pinExists then
            local pins = assert(io.open(policy.obsoletePinList, "wb"))
            assert(pins:close())
        end
        local calls = {}
        local process = {
            run = function(_, name, arguments)
                calls[#calls + 1] = { name = name, arguments = arguments }
                if name == "identity" then return "0\n" end
                if name == "fileMode" then return "81a4\n" end
                if name == "temporary" then return path .. ".tmp\n" end
                if name == "directory" or name == "permissions" then return "" end
                if name == "pacmanRemove" then
                    assert(table.concat(arguments, ",") == "remove-me")
                    return ""
                end
                if name == "removeFile" then
                    assert(os.remove(arguments[1]))
                    return ""
                end
                error("unexpected_run_" .. name)
            end,
            capture = function(_, name, arguments)
                assert(name == "pacmanInstalled")
                if installed[arguments[1]] then return arguments[1] .. "\n", 0 end
                return "", 1
            end,
            status = function(_, name, arguments)
                if name == "isLink" then return link and 0 or 1 end
                if name == "pathExists" then return pinExists and 0 or 1 end
                error("unexpected_status_" .. name)
            end,
        }
        return path, policy, process, calls
    end

    suite:test("package policy keeps established removals and retains native editor packages", function()
        local names = {}
        for _, package in ipairs(sourcePolicy.removePackages) do
            names[package] = true
        end
        assert(names.micro and names["brave-bin"] and names.sushi and names["gtksourceview4"])
        assert(not names["brave-origin-bin"] and not names.neovim and not names["omarchy-nvim"])
    end)

    suite:test("debloat removes only installed packages and atomically clears IgnorePkg", function()
        local path, policy, process, calls = fixture({ ["remove-me"] = true }, nil, true)
        local removed = Debloat.new(process, policy):apply()
        local content = File.read(path)
        assert(removed == 1 and not content:find("IgnorePkg = linux", 1, true))
        assert(content:find("# IgnorePkg = documented", 1, true) and content:find("Color", 1, true))
        assert(calls[#calls].name == "removeFile")
        os.remove(path)
    end)

    suite:test("debloat skips pacman removal when no listed package is installed", function()
        local path, policy, process, calls = fixture({}, "[options]\nColor\n", false)
        assert(Debloat.new(process, policy):apply() == 0)
        for _, call in ipairs(calls) do
            assert(call.name ~= "pacmanRemove")
        end
        os.remove(path)
    end)

    suite:test("debloat rejects redirected pacman files before changing packages", function()
        local path, policy, process, calls = fixture({ ["remove-me"] = true }, nil, false, true)
        suite:reject(function()
            Debloat.new(process, policy):apply()
        end)
        for _, call in ipairs(calls) do
            assert(call.name ~= "pacmanRemove")
        end
        os.remove(path)
    end)

    suite:test("debloat stops when pacman package inspection fails", function()
        local path, policy, process = fixture({}, nil, false)
        process.capture = function()
            return "", 42
        end
        suite:reject(function()
            Debloat.new(process, policy):apply()
        end)
        os.remove(path)
    end)
end
