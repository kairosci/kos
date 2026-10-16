local root = assert(arg[1])
package.path = root .. "/src/?.lua;" .. package.path
local File = require("core.file")
local Json = require("core.json")
local Process = require("core.process")
local Paths = require("core.paths")
local Renderer = require("component.wallpaper.renderer")
local Catalog = require("core.catalog")
local Suite = {}
Suite.__index = Suite

function Suite.new()
    local commands = File.json(root .. "/data/core/commands.json")
    commands.inspect = {"/usr/bin/magick"}
    commands.removeFixture = {"/usr/bin/rm", "-rf", "--"}
    local process = Process.new(commands)
    local directory = process:run("temporary", {"-d"}):gsub("\n$", "")
    return setmetatable({process=process, directory=directory, passed=0, failed=0}, Suite)
end

function Suite:write(path, content)
    self.process:run("directory", {assert(path:match("^(.*)/[^/]+$"))})
    local handle = assert(io.open(path, "wb")); assert(handle:write(content)); assert(handle:close())
end

function Suite:test(name, callback)
    local ok, failure = pcall(callback)
    if ok then self.passed = self.passed + 1; print("  pass " .. name)
    else self.failed = self.failed + 1; print("  fail " .. name .. ": " .. tostring(failure)) end
end

function Suite:finish()
    self.process:run("removeFixture", {self.directory})
    print(("Summary: Tests Executed: %d | Passed: %d | Failed: %d | Warnings: 0"):format(self.passed + self.failed, self.passed, self.failed))
    os.exit(self.failed == 0 and 0 or 1)
end

local suite = Suite.new()
local environment = {HOME=suite.directory}
local paths = Paths.new(File.json(root .. "/data/core/paths.json"), function(key) return environment[key] end)
local current = paths:resolve("state", "omarchy/current")
local output = paths:resolve("config", "os/backgrounds/fixture")
local chooser = paths:resolve("config", "omarchy/backgrounds/fixture")
local policy = File.json(root .. "/data/component/wallpaper/policy.json")
local monitors = '[{"width":1600,"height":900},{"width":1920,"height":1080}]'
local backend = {run=function(_, command, arguments)
    if command == "monitors" then return monitors end
    return suite.process:run(command, arguments)
end}
local catalog = Catalog.new(File.json(root .. "/data/core/locale.json"), root .. "/data/catalog")
local renderer = Renderer.new(root, backend, paths, policy, catalog, function(key) return environment[key] end)
local function palette(accent)
    suite:write(current .. "/theme/colors.toml", 'background = "#112233"\nforeground = "#ffffff"\naccent = "' .. accent .. '"\n')
end
suite:write(current .. "/theme.name", "fixture\n")
suite:write(current .. "/theme/backgrounds/stock.png", File.read(root .. "/" .. policy.logo))
palette("#aabbcc")
local image = output .. "/krepo.png"
local cache
suite:test("Lua renderer produces one palette logo at full monitor geometry", function()
    assert(renderer:render() == image)
    assert(suite.process:run("inspect", {"identify", "-format", "%wx%h", image}) == "1920x1080")
    cache = File.read(output .. "/" .. policy.cache)
end)
suite:test("Lua image pixels follow background and exact accent", function()
    assert(suite.process:run("inspect", {image, "-depth", "8", "-format", "%[hex:p{0,0}]", "info:"}) == "112233")
    assert(suite.process:run("inspect", {image, "-depth", "8", "-unique-colors", "txt:"}):lower():find("#aabbcc", 1, true))
end)
suite:test("active background and native chooser resolve to the generated image", function()
    assert(suite.process:run("realpath", {current .. "/background"}):gsub("\n$", "") == image)
    assert(suite.process:run("realpath", {chooser .. "/krepo.png"}):gsub("\n$", "") == image)
end)
suite:test("stock backgrounds are archived without loss", function()
    assert(#require("component.wallpaper.catalog").new(suite.process, "unused"):entries(current .. "/theme/backgrounds") == 0)
    assert(suite.process:run("runtimeFiles", {paths:resolve("data", "os/retired-backgrounds"), "-name", "stock.png"}):find("stock.png", 1, true))
end)
suite:test("unchanged rendering preserves the cache and image bytes", function()
    local before = File.read(image)
    renderer:render()
    assert(File.read(output .. "/" .. policy.cache) == cache and File.read(image) == before)
end)
suite:test("obsolete variants and personal chooser entries leave a single image", function()
    suite:write(output .. "/krepo-corner.png", "old")
    suite:write(chooser .. "/personal.png", "personal")
    renderer:render()
    local entries = require("component.wallpaper.catalog").new(suite.process, "unused"):entries(chooser)
    assert(#entries == 1 and entries[1] == chooser .. "/krepo.png")
    local retired = suite.process:run("runtimeFiles", {paths:resolve("data", "os/retired-backgrounds"), "-type", "f", "-print0"})
    assert(retired:find("personal.png", 1, true) and retired:find("krepo-corner.png", 1, true))
end)
suite:test("a dangling personal image link is archived before replacement", function()
    local destination = chooser .. "/krepo.png"
    assert(os.remove(destination))
    suite.process:run("symbolicLink", {suite.directory .. "/missing-personal.png", destination})
    renderer:render()
    local retired = suite.process:run("runtimeFiles", {paths:resolve("data", "os/retired-backgrounds"), "-type", "l", "-print0"})
    assert(retired:find("krepo.png", 1, true))
    assert(suite.process:run("realpath", {destination}):gsub("\n$", "") == image)
end)
suite:test("equivalent output paths do not repeatedly archive the active image", function()
    local alias = suite.directory .. "/background-alias"
    suite.process:run("symbolicLink", {output, alias})
    local archive = paths:resolve("data", "os/retired-backgrounds/fixture")
    local before = suite.process:run("runtimeFiles", {archive, "-print0"})
    require("component.wallpaper.catalog").run(root, alias, chooser, archive, root .. "/" .. policy.policyFile)
    assert(suite.process:run("runtimeFiles", {archive, "-print0"}) == before)
end)
suite:test("a missing generated image is restored", function()
    local before = File.read(image)
    assert(os.remove(image)); renderer:render(); assert(File.read(image) == before)
end)
suite:test("monitor changes invalidate the cache", function()
    monitors = '[{"width":2560,"height":1440}]'
    renderer:render()
    assert(suite.process:run("inspect", {"identify", "-format", "%wx%h", image}) == "2560x1440")
end)
suite:test("rotated monitors use physical geometry", function()
    monitors = '[{"width":1920,"height":1080,"transform":1}]'
    renderer:render()
    assert(suite.process:run("inspect", {"identify", "-format", "%wx%h", image}) == "1080x1920")
end)
for _, invalid in ipairs({'[]', '[{"width":0,"height":10}]', '[{"width":10,"height":10,"transform":8}]'}) do
    suite:test("invalid monitor observations preserve the published image " .. invalid, function()
        local before = File.read(image)
        monitors = invalid
        assert(not pcall(renderer.render, renderer))
        assert(File.read(image) == before)
    end)
end
suite:test("invalid palette cannot replace the published image", function()
    local before = File.read(image)
    palette("invalid")
    assert(not pcall(renderer.render, renderer))
    assert(File.read(image) == before)
end)
suite:test("failed native rendering cannot replace the image or cache", function()
    palette("#bbccdd"); monitors = '[{"width":32,"height":32}]'
    local before, previous = File.read(image), File.read(output .. "/" .. policy.cache)
    local failed = {run=function(_, command, arguments)
        if command == "renderWallpaper" then error("fixture_renderer_failure") end
        return backend:run(command, arguments)
    end}
    local instance = Renderer.new(root, failed, paths, policy, catalog, function(key) return environment[key] end)
    assert(not pcall(instance.render, instance))
    assert(File.read(image) == before and File.read(output .. "/" .. policy.cache) == previous)
end)
suite:test("installer activates a validated complete runtime and reuses identical content", function()
    local Installer = require("component.wallpaper.installer")
    local installer = Installer.new(renderer)
    installer:publish()
    local runtime = paths:resolve("data", policy.runtime)
    local active = runtime .. "/" .. policy.runtimeCurrent
    assert(File.read(active .. "/src/component/wallpaper/renderer.lua") == File.read(root .. "/src/component/wallpaper/renderer.lua"))
    assert(File.read(active .. "/data/component/wallpaper/policy.json") == File.read(root .. "/data/component/wallpaper/policy.json"))
    local before = suite.process:run("realpath", {active})
    installer:publish()
    assert(suite.process:run("realpath", {active}) == before)
end)
suite:test("removed source files cannot survive in the active runtime", function()
    local producer = suite.directory .. "/producer"
    suite:write(producer .. "/src/retired.lua", "return true\n")
    suite:write(producer .. "/src/current.lua", "return false\n")
    suite:write(producer .. "/data/policy.json", "{}\n")
    suite:write(producer .. "/script/start", "#!/bin/sh\nexit 0\n")
    local definition = Json.decode(Json.encode(policy))
    definition.runtime = "fixture/runtime"
    local instance = Renderer.new(producer, backend, paths, definition, catalog)
    local installer = require("component.wallpaper.installer").new(instance)
    installer:publish()
    local active = paths:resolve("data", definition.runtime) .. "/" .. definition.runtimeCurrent
    local before = suite.process:run("realpath", {active})
    assert(os.remove(producer .. "/src/retired.lua"))
    installer:publish()
    assert(suite.process:run("realpath", {active}) ~= before)
    assert(not renderer:optional(active .. "/src/retired.lua"))
    assert(File.read(active .. "/src/current.lua") == "return false\n")
end)
suite:test("failed runtime validation preserves the active bundle and removes staging", function()
    local runtime = paths:resolve("data", policy.runtime)
    local active = runtime .. "/" .. policy.runtimeCurrent
    local before = suite.process:run("realpath", {active})
    local failed = {run=function(_, command, arguments)
        if command == "validateLua" then error("fixture_lua_validation_failure") end
        return backend:run(command, arguments)
    end}
    local instance = Renderer.new(root, failed, paths, policy, catalog, function(key) return environment[key] end)
    function instance:optional(path)
        if path:sub(1, #active) == active then return nil end
        return Renderer.optional(self, path)
    end
    local entries = suite.process:run("runtimeFiles", {runtime, "-mindepth", "1", "-maxdepth", "1", "-print0"})
    local installer = require("component.wallpaper.installer").new(instance)
    assert(not pcall(installer.publish, installer))
    assert(suite.process:run("realpath", {active}) == before)
    assert(suite.process:run("runtimeFiles", {runtime, "-mindepth", "1", "-maxdepth", "1", "-print0"}) == entries)
end)
suite:finish()
