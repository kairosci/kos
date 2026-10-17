local File = require("core.file")
local Paths = require("core.paths")
local Publisher = require("core.publisher")
local Catalog = require("core.catalog")
local Helper = require("component.terminal.helper")
local Theme = require("component.terminal.theme")
local Installer = require("component.terminal.installer")

return function(suite, root, process)
    local policy = File.json(root .. "/data/component/terminal/policy.json")
    local directory = process:run("temporary", { "-d" }):gsub("\n$", "")
    local home = directory .. "/home with spaces $literal"
    local layers
    local function environment(name)
        if name == "HOME" then return home end
        if name == "LG_CONFIG_FILE" then return layers end
    end
    local paths = Paths.new(File.json(root .. "/data/core/paths.json"), environment)
    local publisher = Publisher.new(process)
    local function write(path, content)
        process:run("directory", { assert(path:match("^(.*)/[^/]+$")) })
        local file = assert(io.open(path, "wb"))
        assert(file:write(content))
        assert(file:close())
    end
    local palette = paths:resolve("state", policy.theme.palette)
    local colors = {}
    for index, key in ipairs(policy.theme.keys) do
        colors[#colors + 1] = ('%s = "#%06x"\n'):format(key, index)
    end
    local source = table.concat(colors)
    write(palette, source)
    local theme = Theme.new(root, paths, publisher, policy, environment)
    local rc = home .. "/.bashrc"
    local base = paths:resolve("config", policy.theme.base)
    local managed = paths:resolve("config", policy.theme.managed)
    local generated = paths:resolve("config", policy.theme.environment)
    local legacy = paths:resolve("data", policy.legacy)
    write(rc, "export PERSONAL=retained\n")
    process:run("permissions", { "640", rc })
    write(base, "gui:\n  scrollHeight: 7\ncustomCommands: []\n")
    write(legacy, "personal legacy helper\n")
    local original = File.read(base)
    suite:test("all six helper dictionaries preserve every documented tool", function()
        for _, language in ipairs({ "en", "it", "fr", "de", "es", "pt" }) do
            local catalog = Catalog.new(
                File.json(root .. "/data/core/locale.json"),
                root .. "/data/catalog",
                function(name)
                    if name == "OS_LANG" then return language end
                end
            )
            local messages = File.json(root .. "/" .. policy.help:format(language))
            local count = 0
            for _ in pairs(messages) do
                count = count + 1
            end
            assert(count == #policy.topics)
            local output, errors = "", ""
            local helper = Helper.new(root, catalog, policy, {
                write = function(_, ...)
                    output = output .. table.concat({ ... })
                end,
            }, {
                write = function(_, ...)
                    errors = errors .. table.concat({ ... })
                end,
            })
            for _, topic in ipairs(policy.topics) do
                output = ""
                assert(helper:run({ topic, "ignored" }) == 0 and #output > 15)
            end
            for _, alias in ipairs({ "", "list", "ls" }) do
                output = ""
                assert(
                    helper:run({ alias }) == 0
                        and output == messages.index .. (messages.index:sub(-1) == "\n" and "" or "\n")
                )
            end
            assert(helper:run({ "unknown" }) == 1 and errors:find("unknown", 1, true))
        end
    end)
    suite:test("terminal installation preserves personal files and archives legacy helper", function()
        assert(Installer.new(root, paths, publisher, process, policy, environment):install() == "CLI")
        assert(File.read(base) == original)
        assert(File.read(rc):find("export PERSONAL=retained", 1, true))
        assert(tonumber(process:run("fileMode", { rc }), 16) & 0x1FF == tonumber("640", 8))
        assert(File.read(paths:resolve("state", policy.archive)) == "personal legacy helper\n")
        assert(
            tonumber(process:run("fileMode", { paths:resolve("state", policy.archive) }), 16) & 0x1FF
                == tonumber("600", 8)
        )
        assert(process:status("pathExists", { legacy }) == 1)
        assert(not File.read(managed):find("{foreground}", 1, true))
    end)
    suite:test("repeated installation creates one managed block and preserves caller options", function()
        local previous = File.read(rc)
        Installer.new(root, paths, publisher, process, policy, environment):install()
        assert(File.read(rc) == previous)
        local _, count = previous:gsub("# >>> os helpers >>>", "")
        assert(count == 1)
        assert(process
            :run("testShell", {
                "-c",
                'set +e +u; source "$1"; [[ $- != *e* && $- != *u* ]] && declare -F helper',
                "fixture",
                paths:resolve("data", policy.adapter.destination),
            })
            :find("helper", 1, true))
    end)
    suite:test("native LazyGit layers preserve an explicit configuration list without duplication", function()
        layers = "/personal/first.yml,/personal/second.yml," .. managed
        theme:apply()
        local output =
            process:run("testShell", { "-c", 'source "$1"; printf "%s" "$LG_CONFIG_FILE"', "fixture", generated })
        assert(output == layers and File.read(base) == original)
        theme:apply()
        assert(
            process:run("testShell", { "-c", 'source "$1"; printf "%s" "$LG_CONFIG_FILE"', "fixture", generated })
                == layers
        )
        layers = nil
    end)
    suite:test("shell exports quote command substitution characters literally", function()
        layers = "'/personal/$(touch " .. directory .. "/executed).yml"
        theme:apply()
        assert(
            process:run("testShell", { "-c", 'source "$1"; printf "%s" "$LG_CONFIG_FILE"', "fixture", generated })
                == layers .. "," .. managed
        )
        assert(process:status("pathExists", { directory .. "/executed" }) == 1)
        layers = nil
    end)
    suite:test("invalid and missing palettes cannot replace published configuration", function()
        local previous = File.read(generated)
        write(palette, source:gsub("#000001", "$(false)"))
        suite:reject(function()
            theme:apply()
        end)
        assert(File.read(generated) == previous)
        assert(os.remove(palette))
        suite:reject(function()
            theme:apply()
        end)
        assert(File.read(generated) == previous)
        write(palette, source)
    end)
    suite:test("redirected backups and incomplete blocks fail before changing the shell", function()
        local backup = generated .. ".bak"
        local handle = io.open(backup)
        if handle then
            assert(handle:close())
            assert(os.remove(backup))
        end
        process:run("symbolicLink", { directory .. "/absent", backup })
        local previous = File.read(rc)
        suite:reject(function()
            Installer.new(root, paths, publisher, process, policy, environment):install()
        end)
        assert(File.read(rc) == previous)
        assert(os.remove(backup))
        write(rc, "personal\n" .. policy.shell.first .. "\n")
        suite:reject(function()
            Installer.new(root, paths, publisher, process, policy, environment):install()
        end)
        assert(File.read(rc) == "personal\n" .. policy.shell.first .. "\n")
        write(rc, previous)
    end)
    process:run("removeDirectory", { directory })
end
