local File = require("core.file")
local Json = require("core.json")
local Paths = require("core.paths")
local Publisher = require("core.publisher")
local Installer = require("component.editor.neovim.installer")

return function(suite, root, process)
    local policy = File.json(root .. "/data/component/editor/neovim/policy.json")
    suite:test("native editor actions and cancellation work in all six languages", function()
        local originalVim, originalSnacks = _G.vim, _G.Snacks
        local ok, failure = pcall(function()
            for _, language in ipairs({ "en", "it", "fr", "de", "es", "pt" }) do
                local interface = File.json(root .. "/" .. policy.interface)
                interface.messages = File.json(root .. "/" .. policy.catalog:format(language))
                local selected, action, command, help
                _G.vim = {
                    opt = {},
                    json = Json,
                    deepcopy = function(value)
                        return Json.decode(Json.encode(value))
                    end,
                    fn = {
                        stdpath = function(kind)
                            assert(kind == "config")
                            return "/editor/config"
                        end,
                        readfile = function(path)
                            assert(path == "/editor/config/os-editor.json")
                            return { Json.encode(interface) }
                        end,
                    },
                    ui = {
                        select = function(items, options, callback)
                            assert(#items == #interface.menu and options.prompt == interface.messages.settings)
                            callback(selected)
                        end,
                    },
                    api = {
                        nvim_create_user_command = function(name, callback)
                            assert(name == interface.command)
                            command = callback
                        end,
                    },
                    cmd = function(name)
                        action = name
                    end,
                }
                _G.Snacks = {
                    picker = {
                        files = function(options)
                            action = options and options.cwd or "files"
                        end,
                        lines = function()
                            action = "lines"
                        end,
                        grep = function()
                            action = "grep"
                        end,
                    },
                    explorer = function()
                        action = "explorer"
                    end,
                    win = function(options)
                        help = options
                    end,
                }
                local specification = assert(loadfile(root .. "/" .. policy.plugin))()[1]
                assert(specification[1] == interface.plugin)
                specification.init()
                assert(vim.opt.mouse == "a" and vim.opt.confirm and vim.opt.exrc == false and vim.opt.modeline == false)
                local bindings = {}
                for _, binding in ipairs(specification.keys()) do
                    bindings[binding[1]] = binding[2]
                    assert(binding.desc and binding.mode)
                end
                assert(bindings["<C-s>"] == "<Cmd>update<CR>" and bindings["<C-q>"] == "<Cmd>confirm qall<CR>")
                for key, expected in pairs({
                    ["<C-p>"] = "files",
                    ["<C-f>"] = "lines",
                    ["<F2>"] = "explorer",
                    ["<F3>"] = "grep",
                }) do
                    bindings[key]()
                    assert(action == expected)
                end
                for _, item in ipairs(interface.menu) do
                    selected = interface.messages[item.label]
                    bindings["<F4>"]()
                    assert(action == (item.command or "/editor/config"))
                    action = nil
                    command()
                    assert(action == (item.command or "/editor/config"))
                end
                selected, action = nil, nil
                command()
                assert(action == nil)
                bindings["<F1>"]()
                assert(help.enter and help.wo.wrap and help.keys.q == "close" and help.keys["<Esc>"] == "close")
                assert(help.text == interface.messages.help and help.title == interface.messages.title)
            end
        end)
        _G.vim, _G.Snacks = originalVim, originalSnacks
        assert(ok, failure)
    end)
    local directory = process:run("temporary", { "-d" }):gsub("\n$", "")
    local home, native = directory .. "/home", directory .. "/skel"
    local function write(path, content)
        process:run("directory", { assert(path:match("^(.*)/[^/]+$")) })
        local file = assert(io.open(path, "wb"))
        assert(file:write(content))
        assert(file:close())
    end
    local function environment(name)
        if name == "HOME" then
            return home
        elseif name == policy.skeletonVariable then
            return native
        end
    end
    local paths = Paths.new(File.json(root .. "/data/core/paths.json"), environment)
    local publisher = Publisher.new(process)
    local installer = Installer.new(root, paths, publisher, process, policy, { language = "fr" }, environment)
    local config = paths:resolve("config", policy.configuration)
    local cache = paths:resolve("data", policy.cache)
    local rc = home .. "/.bashrc"
    write(native .. "/" .. policy.nativeConfiguration .. "/init.lua", 'require("config.lazy")\n')
    write(native .. "/" .. policy.nativeConfiguration .. "/lua/config/lazy.lua", "return {}\n")
    write(native .. "/" .. policy.nativeCache .. "/example/keep", "packaged cache\n")
    write(rc, "personal shell\n")
    process:run("permissions", { "640", rc })
    suite:test("Neovim seeds packaged configuration and cache with a localized interface", function()
        assert(installer:install() == policy.display)
        assert(File.read(config .. "/init.lua") == 'require("config.lazy")\n')
        assert(File.read(cache .. "/example/keep") == "packaged cache\n")
        assert(
            File.json(config .. "/" .. policy.interfaceDestination).messages.settings == "Paramètres de l’éditeur"
        )
        assert(File.read(rc):find("export EDITOR=nvim", 1, true))
        assert(tonumber(process:run("fileMode", { rc }), 16) & 0x1FF == tonumber("640", 8))
    end)
    suite:test("Neovim preserves personal options plugins and shell content on repeat", function()
        write(config .. "/lua/config/options.lua", "personal options\n")
        write(cache .. "/example/keep", "personal cache\n")
        local before = File.read(rc)
        installer:install()
        assert(File.read(config .. "/lua/config/options.lua") == "personal options\n")
        assert(File.read(cache .. "/example/keep") == "personal cache\n" and File.read(rc) == before)
        assert(File.read(config .. "/" .. policy.pluginDestination) == File.read(root .. "/" .. policy.plugin))
    end)
    suite:test("the application dispatcher applies only the selected editor", function()
        local output, status = process:capture("environment", {
            "HOME=" .. home,
            "XDG_CONFIG_HOME=" .. home .. "/.config",
            "XDG_DATA_HOME=" .. home .. "/.local/share",
            "XDG_STATE_HOME=" .. home .. "/.local/state",
            "OS_NVIM_SKEL=" .. native,
            "OS_LANG=it",
            "/usr/bin/lua",
            "-E",
            root .. "/src/main.lua",
            root,
            "apply-applications",
            "neovim",
        }, true)
        assert(status == 0, output)
        assert(output == "Integrazione desktop installata: Neovim\n")
    end)
    suite:test("Neovim rejects redirected plugin directories without touching personal files", function()
        local target = config .. "/lua/plugins"
        process:run("move", { target, directory .. "/plugins" })
        process:run("symbolicLink", { directory .. "/plugins", target })
        local previous = File.read(rc)
        suite:reject(function()
            installer:install()
        end)
        assert(File.read(rc) == previous)
        assert(os.remove(target))
        process:run("move", { directory .. "/plugins", target })
    end)
    suite:test("incompatible editor configurations remain untouched", function()
        local lazy = config .. "/" .. policy.lazyConfiguration
        local content, previous = File.read(lazy), File.read(rc)
        assert(os.remove(lazy))
        suite:reject(function()
            installer:install()
        end)
        assert(File.read(rc) == previous and File.read(cache .. "/example/keep") == "personal cache\n")
        write(lazy, content)
    end)
    suite:test("redirected editor backups fail before publishing any configuration", function()
        local backup = config .. "/" .. policy.pluginDestination .. ".bak"
        local handle = io.open(backup)
        if handle then
            handle:close()
            assert(os.remove(backup))
        end
        process:run("symbolicLink", { directory .. "/absent", backup })
        local previous = File.read(rc)
        suite:reject(function()
            installer:install()
        end)
        assert(File.read(rc) == previous)
        assert(os.remove(backup))
    end)
    suite:test("missing packaged cache cannot publish a new editor configuration", function()
        local missingHome = directory .. "/new-home"
        local isolated = Paths.new(File.json(root .. "/data/core/paths.json"), function(name)
            if name == "HOME" then return missingHome end
        end)
        process:run("removeDirectory", { native .. "/" .. policy.nativeCache })
        suite:reject(function()
            Installer.new(root, isolated, publisher, process, policy, { language = "en" }, environment):install()
        end)
        assert(process:status("pathExists", { missingHome .. "/.config/nvim/init.lua" }) == 1)
    end)
    suite:test("failed cache staging leaves shell and editor initialization unpublished", function()
        local isolatedHome = directory .. "/copy-failure"
        write(isolatedHome .. "/.bashrc", "retained shell\n")
        write(native .. "/" .. policy.nativeCache .. "/example/keep", "packaged\n")
        local isolated = Paths.new(File.json(root .. "/data/core/paths.json"), function(name)
            if name == "HOME" then return isolatedHome end
        end)
        local backend = {
            run = function(_, name, arguments)
                assert(name ~= "copyTree", "simulated_cache_copy_failure")
                return process:run(name, arguments)
            end,
            status = function(_, name, arguments)
                return process:status(name, arguments)
            end,
        }
        suite:reject(function()
            Installer.new(root, isolated, publisher, backend, policy, { language = "en" }, environment):install()
        end)
        assert(File.read(isolatedHome .. "/.bashrc") == "retained shell\n")
        assert(process:status("pathExists", { isolatedHome .. "/.config/nvim/init.lua" }) == 1)
        assert(process:run("runtimeFiles", { isolatedHome .. "/.local/share/nvim", "-mindepth", "1", "-print" }) == "")
    end)
    process:run("removeDirectory", { directory })
end
