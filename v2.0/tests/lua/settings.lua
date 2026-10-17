local File = require("core.file")
local Json = require("core.json")
local Model = require("component.settings.model")
local Paths = require("core.paths")
local Publisher = require("core.publisher")

return function(suite, root, process)
    local directory = process:run("temporary", {"-d"}):gsub("\n$", "")
    local policy = File.json(root .. "/data/component/settings/policy.json")
    local paths = Paths.new(File.json(root .. "/data/core/paths.json"), function(key)
        if key == "HOME" then return directory end
    end)
    local publisher = Publisher.new(process)
    publisher:publish(paths:resolve("config", policy.sessionConfiguration), [[{"idle":{"lock":300,"screensaver":150},"personal":true}]], "600")
    local main = paths:resolve("config", policy.main)
    publisher:publish(main, "hl.config({})\n" .. policy.include .. "\n", "600")
    local stateFile = paths:resolve("config", policy.state)
    local generated = paths:resolve("config", policy.generated)
    publisher:publish(generated, "hl.config({})\n", "600")
    publisher:publish(paths:resolve("state", policy.palette.path), 'background="#111111"\nforeground="#eeeeee"\ndark_background="#000000"\nlighter_background="#222222"\naccent="#aabbcc"\n', "600")
    local values, counts = Json.array({}), {}
    for _, option in ipairs(policy.options) do
        values[#values + 1] = {name=option.key, current=option.kind == "boolean" and false or option.kind == "number" and option.min or "it"}
        if option.kind == "boolean" then values[#values].current = false end
        if option.kind == "choice" then values[#values].current = option.choices[1] end
    end
    local backend = {failure=nil, run=function(self, command, arguments)
        counts[command] = (counts[command] or 0) + 1
        if self.failure == command then error("fixture_failure_" .. command) end
        if command == "settingsDescriptions" then return Json.encode(values) end
        if command == "settingsValidate" then
            local staging = arguments[1]:match("^XDG_CONFIG_HOME=(.*)$")
            assert(File.read(staging .. "/" .. policy.main):find(policy.include, 1, true))
            process:run("validateLua", {staging .. "/" .. policy.generated})
            return policy.validationSuccess .. "\n"
        end
        if command == "settingsQml" then
            local manifest = arguments[1]:match("^OS_SETTINGS_COMPONENTS=(.*)$")
            assert(#File.json(manifest) >= 6)
            return "settings-components-valid"
        end
        if command == "settingsReload" or command == "settingsErrors" or command == "desktopDatabase" then return "" end
        return process:run(command, arguments)
    end}
    local catalog = {messages={["settings.title"]="Settings"}, text=function(_, key) assert(key == "settings.title"); return "Settings" end}
    local model = Model.new(root, backend, paths, publisher, policy, catalog)
    suite:test("settings snapshot reads native values and validates palette without writes", function()
        local result = model:snapshot()
        assert(#result.options == #policy.options and result.options[1].value == policy.options[1].min)
        assert(result.palette.highlight == "#aabbcc" and result.labels.title == "Settings")
        assert(not counts.settingsReload and not counts.copyTree)
    end)
    suite:test("settings rejects unknown keys injection invalid types and out of range values", function()
        for _, item in ipairs({{"exec", "bad"}, {"general:border_size", 99}, {"general:border_size", 1.5}, {"animations:enabled", "true"}, {"input:kb_layout", 'it\"); os.execute("bad")'}, {"input:kb_layout", "../it"}}) do
            suite:reject(function() model:write(table.unpack(item)) end)
        end
        assert(not counts.settingsValidate and not counts.settingsReload)
    end)
    suite:test("settings publishes only validated native Lua and private persistent state", function()
        model:write("general:border_size", 3)
        assert(Json.decode(File.read(stateFile))["general:border_size"] == 3)
        local emitted = File.read(generated)
        assert(emitted:find('["border_size"]=3', 1, true))
        assert(tonumber(process:run("fileMode", {stateFile}), 16) & 0x1FF == 0x180)
        assert(File.read(main) == "hl.config({})\n" .. policy.include .. "\n")
        model:write("input:touchpad:tap-to-click", true)
        assert(File.read(generated):find('["tap-to-click"]=true', 1, true))
        assert(Json.decode(File.read(stateFile))["general:border_size"] == 3)
    end)
    suite:test("failed compositor validation cannot replace active settings", function()
        local before, original = File.read(generated), File.read(stateFile)
        backend.failure = "settingsValidate"
        suite:reject(function() model:write("general:border_size", 4) end)
        backend.failure = nil
        assert(File.read(generated) == before and File.read(stateFile) == original)
    end)
    suite:test("failed live reload restores generated settings and preserves state", function()
        local before, original = File.read(generated), File.read(stateFile)
        backend.failure = "settingsErrors"
        suite:reject(function() model:write("general:border_size", 5) end)
        backend.failure = nil
        assert(File.read(generated) == before and File.read(stateFile) == original)
    end)
    suite:test("settings state corruption fails before any native activation", function()
        local original, reloads = File.read(stateFile), counts.settingsReload
        publisher:publish(stateFile, '{"unknown":true}', "600")
        suite:reject(function() model:write("general:border_size", 2) end)
        assert(counts.settingsReload == reloads)
        publisher:publish(stateFile, original, "600")
    end)
    suite:test("settings rejects null arrays and scalar state without activation", function()
        local original, reloads = File.read(stateFile), counts.settingsReload
        for _, invalid in ipairs({"null", "[]", "false", "42", "\"value\""}) do
            publisher:publish(stateFile, invalid, "600")
            suite:reject(function() model:state() end)
        end
        assert(counts.settingsReload == reloads)
        publisher:publish(stateFile, original, "600")
    end)
    suite:test("session settings persist timers without replacing unrelated desktop preferences", function()
        local Session = require("component.settings.session")
        local session = Session.new(paths, publisher, policy)
        session:write("lock", 450)
        local config = File.json(paths:resolve("config", policy.sessionConfiguration))
        assert(config.personal and config.idle.lock == 450 and config.idle.screensaver == 150)
        assert(session:snapshot()[1].value == 450)
        local before = File.read(paths:resolve("config", policy.sessionConfiguration))
        suite:reject(function() session:write("lock", 1) end)
        suite:reject(function() session:write("screensaver", 0.5) end)
        suite:reject(function() session:write("exec", 60) end)
        assert(File.read(paths:resolve("config", policy.sessionConfiguration)) == before)
    end)
    suite:test("invalid theme data cannot become application palette", function()
        publisher:publish(paths:resolve("state", policy.palette.path), 'accent="#bad"', "600")
        suite:reject(function() model:snapshot() end)
    end)
    suite:test("settings installer stays idempotent when another producer appends an include", function()
        local Installer = require("component.settings.installer")
        local installer = Installer.new(model)
        publisher:publish(main, "hl.config({})\n" .. policy.include .. "\nrequire(\"hyprland-gui\")\n", "600")
        installer:apply()
        local expected = "hl.config({})\nrequire(\"hyprland-gui\")\n" .. policy.include .. "\n"
        assert(File.read(main) == expected)
        local active = paths:resolve("data", policy.runtime) .. "/" .. policy.runtimeCurrent
        local before = process:run("realpath", {active})
        installer:apply()
        assert(File.read(main) == expected and process:run("realpath", {active}) == before)
        local launcher = paths:resolve("home", ".local/" .. policy.launcher)
        assert(tonumber(process:run("fileMode", {launcher}), 16) & 0x1FF == 0x1ED)
        assert(File.read(paths:resolve("data", policy.desktop)):find("Exec=os-settings", 1, true))
        local previous = File.read(main)
        backend.failure = "settingsValidate"
        suite:reject(function() installer:apply() end)
        backend.failure = nil
        assert(File.read(main) == previous and process:run("realpath", {active}) == before)
    end)
    process:run("removeDirectory", {directory})
end
