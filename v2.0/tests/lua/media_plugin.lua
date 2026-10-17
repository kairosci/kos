local File = require("core.file")
local Paths = require("core.paths")
local Plugin = require("component.media.plugin")
local Publisher = require("core.publisher")
local Namespace = require("core.user_configuration")

return function(suite, root, process)
    local directory = process:run("temporary", {"-d"}):gsub("\n$", "")
    local project, home = directory .. "/project", directory .. "/home"
    local registry = File.json(root .. "/data/component/application/policy.json")
    local policy = registry.osmp
    local function write(path, content)
        process:run("directory", {assert(path:match("^(.*)/[^/]+$"))})
        local file = assert(io.open(path, "wb")); assert(file:write(content)); assert(file:close())
    end
    process:run("directory", {project .. "/" .. policy.source, home})
    for path in process:run("runtimeFiles", {root .. "/" .. policy.source, "-type", "f", "-print0"}):gmatch("[^%z]+") do
        write(project .. "/" .. policy.source .. "/" .. assert(path:match("([^/]+)$")), File.read(path))
    end
    for _, entry in ipairs(policy.files) do write(project .. "/" .. entry.source, File.read(root .. "/" .. entry.source)) end
    write(project .. "/" .. policy.package, File.read(root .. "/" .. policy.package))
    write(project .. "/" .. policy.namespace, File.read(root .. "/" .. policy.namespace))
    write(home .. "/.config/omarchy/personal.json", "personal settings\n")
    local function environment(name)
        if name == "HOME" then return home end
        if name == "OMARCHY_PATH" then return directory .. "/native" end
    end
    local paths = Paths.new(File.json(root .. "/data/core/paths.json"), environment)
    local target = paths:resolve("config", policy.target)
    local failure, validated, validations = false, nil, 0
    local backend = {run=function(_, name, arguments)
        if name == "environment" then
            validations = validations + 1
            assert(arguments[1] == directory .. "/native/" .. policy.validator.entry and arguments[2] == "plugin" and arguments[3] == "validate")
            local stage = arguments[#arguments]
            assert(stage ~= project .. "/" .. policy.source)
            assert(File.json(stage .. "/manifest.json").id == policy.identity)
            assert(File.read(stage .. "/src/BarWidget.qml") ~= "")
            assert(File.read(stage .. "/LICENSE") == File.read(root .. "/docs/en/modules/plugins/osmp/LICENSE"))
            assert(process:run("runtimeFiles", {stage, "-type", "l", "-print"}) == "")
            assert(not failure, "native_validation_failed")
            validated = stage
            return ""
        end
        return process:run(name, arguments)
    end, status=function(_, name, arguments) return process:status(name, arguments) end}
    local plugin = Plugin.new(project, paths, Publisher.new(process), backend, registry, environment)
    suite:test("OSMP validates a standalone regular payload before installation", function()
        assert(plugin:apply("osmp") == policy.display and validated)
        assert(File.read(target .. "/manifest.json") == File.read(project .. "/" .. policy.manifest))
        assert(File.read(target .. "/LICENSE") == File.read(root .. "/docs/en/modules/plugins/osmp/LICENSE"))
        assert(process:run("runtimeFiles", {target, "-type", "l", "-print"}) == "")
        assert(File.read(home .. "/.config/os/personal.json") == "personal settings\n")
        assert(process:run("readLink", {home .. "/.config/omarchy"}):gsub("\n$", "") == "os")
    end)
    suite:test("repeated OSMP installation preserves runtime content", function()
        local previous = File.read(target .. "/src/BarWidget.qml")
        assert(plugin:apply("osmp") == policy.display and File.read(target .. "/src/BarWidget.qml") == previous)
    end)
    suite:test("failed native validation cannot replace installed runtime", function()
        local path = project .. "/" .. policy.source .. "/BarWidget.qml"
        local original, previous = File.read(path), File.read(target .. "/src/BarWidget.qml")
        write(path, "invalid new source"); failure = true
        suite:reject(function() plugin:apply("osmp") end)
        assert(File.read(target .. "/src/BarWidget.qml") == previous)
        failure = false; write(path, original)
    end)
    suite:test("source links and version mismatches fail before native validation", function()
        local unsafe = project .. "/" .. policy.source .. "/unsafe.qml"
        process:run("symbolicLink", {project .. "/" .. policy.manifest, unsafe})
        local before = validations
        suite:reject(function() plugin:apply("osmp") end)
        assert(validations == before); assert(os.remove(unsafe))
        local manifest = project .. "/" .. policy.manifest
        local original = File.read(manifest)
        write(manifest, original:gsub('"1%.5%.0"', '"0.0.0"'))
        suite:reject(function() plugin:apply("osmp") end)
        assert(validations == before); write(manifest, original)
    end)
    suite:test("redirected destination backups cannot cause partial publication", function()
        local backup = target .. "/LICENSE.bak"
        local previous = File.read(target .. "/src/BarWidget.qml")
        process:run("symbolicLink", {directory .. "/absent", backup})
        suite:reject(function() plugin:apply("osmp") end)
        assert(File.read(target .. "/src/BarWidget.qml") == previous)
        assert(os.remove(backup))
    end)
    suite:test("configuration collisions are rejected before moving any entries", function()
        local isolated = directory .. "/collision"
        local namespacePaths = Paths.new(File.json(root .. "/data/core/paths.json"), function(name) if name == "HOME" then return isolated end end)
        local namespace = Namespace.new(namespacePaths, process, File.json(root .. "/data/core/user-configuration.json"))
        write(isolated .. "/.config/omarchy/first", "retained\n")
        write(isolated .. "/.config/omarchy/collision", "old\n")
        write(isolated .. "/.config/os/collision", "personal\n")
        suite:reject(function() namespace:migrate() end)
        assert(File.read(isolated .. "/.config/omarchy/first") == "retained\n")
        assert(File.read(isolated .. "/.config/omarchy/collision") == "old\n")
        assert(File.read(isolated .. "/.config/os/collision") == "personal\n")
    end)
    suite:test("unexpected namespace links cannot redirect application installation", function()
        local isolated = directory .. "/redirected"
        local namespacePaths = Paths.new(File.json(root .. "/data/core/paths.json"), function(name) if name == "HOME" then return isolated end end)
        process:run("directory", {isolated .. "/.config"})
        process:run("symbolicLink", {directory, isolated .. "/.config/os"})
        suite:reject(function() Namespace.new(namespacePaths, process, File.json(root .. "/data/core/user-configuration.json")):migrate() end)
        assert(process:status("pathExists", {isolated .. "/.config/omarchy"}) == 1)
    end)
    process:run("removeDirectory", {directory})
end
