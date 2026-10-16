local root = assert(arg[1])
package.path = root .. "/src/?.lua;" .. package.path
local File = require("core.file")
local Process = require("core.process")
local commands = File.json(root .. "/data/core/commands.json")
commands.environment = {"/usr/bin/env"}
commands.find = {"/usr/bin/find"}
commands.link = {"/usr/bin/ln", "-s", "--"}
commands.removeTree = {"/usr/bin/rm", "-r", "--"}
local process = Process.new(commands)
local directory = process:run("temporary", {"-d"}):gsub("\n$", "")
local project = directory .. "/project"
local source = project .. "/modules/plugins/osmp"
local home = directory .. "/home"
local destination = home .. "/.config/os/plugins/os.osmp"
local function write(path, content)
    local file = assert(io.open(path, "w")); assert(file:write(content)); assert(file:close())
end
for _, path in ipairs({project .. "/scripts/lib", project .. "/modules/conf/osmp", source .. "/src", project .. "/docs/modules/plugins/osmp", directory .. "/bin", home}) do process:run("directory", {path}) end
for _, path in ipairs({"scripts/lib/i18n.sh", "scripts/lib/userconf.sh", "modules/conf/osmp/install.sh", "docs/modules/plugins/osmp/LICENSE", "modules/plugins/osmp/manifest.json"}) do process:run("copy", {root .. "/" .. path, project .. "/" .. path}) end
for path in process:run("find", {root .. "/modules/plugins/osmp/src", "-maxdepth", "1", "-type", "f", "-print0"}):gmatch("[^%z]+") do
    process:run("copy", {path, source .. "/src/" .. path:match("[^/]+$")})
end
process:run("link", {"/missing-metadata-target", source .. "/.agents"})
write(directory .. "/bin/omarchy", [=[#!/usr/bin/env bash
set -euo pipefail
[[ "$1 $2" == 'plugin validate' ]]
[[ -f "$3/manifest.json" && -f "$3/src/BarWidget.qml" && -f "$3/LICENSE" ]]
[[ -z "$(find "$3" -type l -print -quit)" ]]
printf '%s\n' "$3" > "$OSMP_TEST_VALIDATED"
[[ "${OSMP_TEST_FAIL:-0}" == 0 ]]
]=])
process:run("permissions", {"755", directory .. "/bin/omarchy"})
local Suite = {}
Suite.__index = Suite
function Suite.new() return setmetatable({passed=0, failed=0}, Suite) end
function Suite:test(name, callback)
    local ok, failure = pcall(callback)
    if ok then self.passed = self.passed + 1; print("  pass " .. name)
    else self.failed = self.failed + 1; print("  fail " .. name .. ": " .. tostring(failure)) end
end
local suite = Suite.new()
local function install(fail)
    return process:run("environment", {"HOME=" .. home, "XDG_CONFIG_HOME=" .. home .. "/.config", "XDG_DATA_HOME=" .. home .. "/.local/share", "XDG_STATE_HOME=" .. home .. "/.local/state", "OS_I18N_DIR=" .. root .. "/data/catalog", "OS_LANG=en", "PATH=" .. directory .. "/bin:/usr/bin:/bin", "OSMP_TEST_VALIDATED=" .. directory .. "/validated", "OSMP_TEST_FAIL=" .. (fail and "1" or "0"), "bash", project .. "/modules/conf/osmp/install.sh"})
end
suite:test("OSMP validates a standalone payload without repository metadata", function()
    install()
    assert(File.read(directory .. "/validated"):gsub("\n$", "") ~= source)
    assert(File.read(destination .. "/manifest.json") == File.read(source .. "/manifest.json"))
end)
suite:test("OSMP installs canonical license as a regular runtime file", function()
    assert(File.read(destination .. "/LICENSE") == File.read(project .. "/docs/modules/plugins/osmp/LICENSE"))
    assert(process:run("find", {destination, "-type", "l", "-print"}) == "")
end)
suite:test("OSMP repeated installation preserves runtime content", function()
    local previous = File.read(destination .. "/src/BarWidget.qml")
    install()
    assert(File.read(destination .. "/src/BarWidget.qml") == previous)
end)
suite:test("failed native validation cannot replace installed runtime", function()
    local previous = File.read(destination .. "/src/BarWidget.qml")
    write(source .. "/src/BarWidget.qml", "invalid new source")
    assert(not pcall(install, true))
    assert(File.read(destination .. "/src/BarWidget.qml") == previous)
end)
suite:test("symlinks inside executable payload are rejected before publication", function()
    process:run("link", {source .. "/manifest.json", source .. "/src/unsafe.qml"})
    local previous = File.read(destination .. "/src/BarWidget.qml")
    assert(not pcall(install))
    assert(File.read(destination .. "/src/BarWidget.qml") == previous and not io.open(destination .. "/src/unsafe.qml"))
end)
process:run("removeTree", {directory})
print(("Summary: Tests Executed: %d | Passed: %d | Failed: %d | Warnings: 0"):format(suite.passed + suite.failed, suite.passed, suite.failed))
os.exit(suite.failed == 0 and 0 or 1)
