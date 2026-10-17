local File = require("core.file")
local Json = require("core.json")
local Cli = require("component.cli.application")
local Catalog = require("core.catalog")

return function(suite, root, process)
    local directory = process:run("temporary", {"-d"}):gsub("\n$", "")
    local environment = {HOME=directory .. "/home", PATH=directory .. "/bin", XDG_DATA_HOME=directory .. "/data", XDG_DATA_DIRS=directory .. "/system", OMARCHY_PATH=directory .. "/native", OS_LANG="en", XDG_RUNTIME_DIR=directory .. "/runtime", DBUS_SESSION_BUS_ADDRESS="unix:path=" .. directory .. "/runtime/bus"}
    local function write(path, content)
        process:run("directory", {assert(path:match("^(.*)/[^/]+$"))})
        local handle = assert(io.open(path, "wb")); assert(handle:write(content)); assert(handle:close())
    end
    local function getenv(name) return environment[name] end
    local policy = File.json(root .. "/data/component/cli/policy.json")
    local catalog = Catalog.new(File.json(root .. "/data/core/locale.json"), root .. "/data/catalog", getenv)
    local browser, queryFailure, launchStatus, launched, delegated = "browser.desktop", false, 0
    local launcherAvailable = true
    local output = {text="", write=function(self, ...) for _, word in ipairs({...}) do self.text = self.text .. word end end}
    local backend = {
        run=function(_, name, arguments)
            if name == "identity" then return "1000\n" end
            if name == "environment" then
                assert(not queryFailure, "default_query_failed")
                if arguments[1] == "-u" then assert(arguments[2] == "BROWSER"); return browser .. "\n" end
                local mime = arguments[#arguments]
                return assert(({["text/plain"]="editor.desktop",["inode/directory"]="files.desktop",["x-scheme-handler/https"]="fallback.desktop"})[mime]) .. "\n"
            end
            return process:run(name, arguments)
        end,
    }
    backend.status = function(_, name, arguments)
        if name == "environment" then
            if arguments[1] == "uwsm-app" then launched = arguments else delegated = arguments end
            return launchStatus
        end
        if name == "isExecutable" then
            if (arguments[1] == directory .. "/bin/uwsm-app" and launcherAvailable) or arguments[1] == directory .. "/bin/omarchy" then return 0 end
            return 1
        end
        return process:status(name, arguments)
    end
    local cli = Cli.new(root, backend, catalog, policy, getenv, output)
    for _, name in ipairs({"browser", "fallback", "editor", "files", "os.settings"}) do
        write(directory .. "/system/applications/" .. name .. ".desktop", "[Desktop Entry]\nType=Application\nName=Fixture\nExec=fixture %U\n")
    end
    local browserFile = directory .. "/system/applications/browser.desktop"
    local original = File.read(browserFile) .. "Actions=new-private-window;\n[Desktop Action new-private-window]\nExec=fixture --incognito %U\n"
    write(browserFile, original)
    local function resolve(role, ...)
        output.text = ""
        assert(cli:app({"--resolve", role, ...}) == 0)
        return Json.decode(output.text)
    end
    suite:test("browser resolution preserves URLs and bypasses ambient BROWSER", function()
        local url = "https://example.org/a b?x=1&y=2"
        local result = resolve("browser", url)
        assert(result.desktop == "browser.desktop" and result.argv[4] == url and not launched and not delegated)
    end)
    suite:test("private browser resolution requires its declared desktop action", function()
        assert(resolve("browser", "--private").desktop == "browser.desktop:new-private-window")
        browser = "fallback.desktop"
        suite:reject(function() cli:app({"browser", "--private"}) end)
        browser = "browser.desktop"
    end)
    suite:test("an empty browser preference uses its HTTPS MIME association", function()
        browser = ""; assert(resolve("browser").desktop == "fallback.desktop"); browser = "browser.desktop"
    end)
    suite:test("failed queries and invalid identifiers cannot launch applications", function()
        queryFailure = true; suite:reject(function() cli:app({"browser"}) end); queryFailure = false
        browser = "../browser.desktop"; suite:reject(function() cli:app({"browser"}) end); browser = "browser.desktop"
        assert(not launched)
    end)
    suite:test("unknown roles and flags cannot reach the launcher", function()
        suite:reject(function() cli:app({"missing"}) end)
        suite:reject(function() cli:app({"browser", "--incognito"}) end)
        assert(not launched)
    end)
    suite:test("editor files and settings resolve their independent desktop roles", function()
        assert(resolve("editor", "/tmp/file with spaces").argv[4] == "/tmp/file with spaces")
        assert(resolve("files").desktop == "files.desktop")
        assert(resolve("settings").desktop == "os.settings.desktop")
    end)
    suite:test("hidden user overrides prevent system launcher activation", function()
        local path = directory .. "/data/applications/browser.desktop"
        write(path, "[Desktop Entry]\nType=Application\nHidden=true\nExec=fixture\n")
        suite:reject(function() cli:app({"browser"}) end)
        write(path, "[Desktop Entry]\nType=Application\nExec=personal\n")
        assert(resolve("browser").desktopFile == path)
        assert(os.remove(path))
    end)
    suite:test("nested desktop identifiers resolve without executing their Exec data", function()
        local nested = directory .. "/system/applications/nested/browser.desktop"
        write(nested, original); assert(os.remove(browserFile))
        browser = "nested-browser.desktop"; assert(resolve("browser").desktopFile == nested)
        write(browserFile, original); assert(os.remove(nested)); browser = "browser.desktop"
    end)
    suite:test("application launch preserves literal arguments and native exit status", function()
        assert(cli:app({"files", "$(touch never-execute)"}) == 0)
        assert(launched[1] == "uwsm-app" and launched[2] == "--" and launched[3] == "files.desktop" and launched[4] == "$(touch never-execute)")
        launchStatus = 37; assert(cli:app({"settings"}) == 37); launchStatus = 0
    end)
    suite:test("native delegation preserves arguments runtime environment and failure status", function()
        launchStatus = 37
        assert(cli:runtime({"theme", "two words"}) == 37)
        assert(delegated[1] == "OMARCHY_PATH=" .. environment.OMARCHY_PATH and delegated[2] == "omarchy" and delegated[3] == "theme" and delegated[4] == "two words")
        launchStatus = 0
    end)
    suite:test("changelog release extraction and help use their canonical data", function()
        output.text = ""; cli:run({"--help"}); assert(output.text:find("os <group> <command>", 1, true))
        output.text = ""; cli:changelog("1.0"); assert(output.text:find("## Release v1.0", 1, true))
        output.text = ""; cli:changelog("unreleased"); assert(output.text:find("## Unreleased", 1, true))
        suite:reject(function() cli:changelog("v9.9") end)
        local changelog = File.read(root .. "/CHANGELOG.md")
        assert(changelog:find("single narrative source", 1, true))
        for _, version in ipairs({"1.0", "1.1", "1.2", "1.3", "1.4"}) do assert(changelog:find("## Release v" .. version, 1, true)) end
        for line in changelog:gmatch("[^\n]+") do assert(not line:match("^%s*[-*+]%s+") and not line:match("^%s*%d+[.)]%s+")) end
    end)
    suite:test("app help follows the selected catalog", function()
        local italian = Catalog.new(File.json(root .. "/data/core/locale.json"), root .. "/data/catalog", function(name) if name == "OS_LANG" then return "it" end end)
        local localized = Cli.new(root, backend, italian, policy, getenv, output)
        output.text = ""; localized:app({"--help"}); assert(output.text:find("Uso:", 1, true))
    end)
    suite:test("invalid desktop sections cannot redirect a launch", function()
        write(browserFile, "[Desktop Entry]\nType=Application\nType=Link\nExec=fixture\n")
        suite:reject(function() resolve("browser") end)
        write(browserFile, "[Desktop Entry]\nType=Link\nURL=https://example.org\n")
        suite:reject(function() resolve("browser") end)
        write(browserFile, original)
    end)
    suite:test("empty XDG variables retain standard preference semantics", function()
        local previous = policy.dataDirectories
        policy.dataDirectories = directory .. "/system"
        environment.XDG_DATA_HOME, environment.XDG_DATA_DIRS = "", ""
        local path = environment.HOME .. "/" .. policy.dataHomeRelative .. "/applications/browser.desktop"
        write(path, original)
        assert(resolve("browser").desktopFile == path)
        assert(os.remove(path))
        assert(resolve("browser").desktopFile == browserFile)
        environment.XDG_DATA_HOME, environment.XDG_DATA_DIRS = directory .. "/data", directory .. "/system"
        policy.dataDirectories = previous
    end)
    suite:test("missing launcher and native runtime fail before execution", function()
        launcherAvailable = false
        suite:reject(function() resolve("browser") end)
        launcherAvailable = true
        environment.PATH = directory .. "/empty"
        suite:reject(function() cli:runtime({"commands"}) end)
        environment.PATH = directory .. "/bin"
    end)
    suite:test("the essential starter exposes help and fails on missing commands", function()
        local text, status = process:capture("environment", {"OS_LANG=en", root .. "/script/os", "--help"}, true)
        assert(status == 0 and text:find("os <group> <command>", 1, true))
        local _, failure = process:capture("environment", {"OS_LANG=en", root .. "/script/os"}, true)
        assert(failure ~= 0)
    end)
    process:run("removeDirectory", {directory})
end
