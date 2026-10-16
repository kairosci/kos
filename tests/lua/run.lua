local root = assert(arg[1])
package.path = root .. "/src/?.lua;" .. package.path
local Json = require("core.json")
local File = require("core.file")
local Process = require("core.process")
local Catalog = require("core.catalog")
local Menu = require("component.boot.menu")
local Publisher = require("core.publisher")
local Suite = {}
Suite.__index = Suite

function Suite.new()
    return setmetatable({passed=0, failed=0}, Suite)
end

function Suite:test(name, callback)
    local ok, failure = pcall(callback)
    if ok then self.passed = self.passed + 1; print("  pass " .. name)
    else self.failed = self.failed + 1; print("  fail " .. name .. ": " .. tostring(failure)) end
end

function Suite:reject(callback)
    assert(not pcall(callback), "invalid_input_accepted")
end

function Suite:finish()
    print(("Summary: Tests Executed: %d | Passed: %d | Failed: %d | Warnings: 0"):format(self.passed + self.failed, self.passed, self.failed))
    os.exit(self.failed == 0 and 0 or 1)
end

local suite = Suite.new()
local process = Process.new(File.json(root .. "/data/core/commands.json"))
local menu = Menu.new(process, File.json(root .. "/data/component/boot/render.json"))
local policy = File.json(root .. "/data/component/boot/policy.json").menu
local function source(path, command)
    return "/Arch\n //linux\n protocol: efi\n path: boot():" .. path .. "\n cmdline: " .. (command or "cryptdevice=fixture root=/dev/mapper/root rootflags=subvol=@ resume_offset=123 lsm=apparmor") .. "\n"
end

if arg[2] == "json" then
    suite:test("JSON round trips arrays false null and Unicode", function()
        local value = Json.decode([[{"values":[false,null,"\uD83D\uDE00",1.25e2]}]])
        assert(value.values[1] == false and value.values[2] == Json.null and value.values[3] == "😀" and value.values[4] == 125)
        assert(Json.encode(Json.decode(Json.encode(value))) == Json.encode(value))
    end)
    for _, invalid in ipairs({'{"key":1,"key":2}', '[1,]', '01', '+1', '1.', '1e+', 'true false', '"\\uD800"', '"\\x"', '{"x" 1}', '"raw\nline"'}) do
        suite:test("JSON rejects invalid input " .. Json.encode(invalid), function() suite:reject(function() Json.decode(invalid) end) end)
    end
    suite:test("process argument quoting never executes shell substitutions", function()
        local runner = Process.new({print={"/usr/bin/printf", "%s"}})
        local argument = "a' b $(exit 43); `exit 44`"
        assert(runner:run("print", {argument}) == argument)
    end)
    suite:test("failed native processes propagate", function()
        local runner = Process.new({fail={"/usr/bin/false"}})
        suite:reject(function() runner:run("fail") end)
    end)
elseif arg[2] == "catalog" then
    local locale = File.json(root .. "/data/core/locale.json")
    for _, language in ipairs(locale.languages) do
        suite:test("catalog selects " .. language .. " with environment precedence", function()
            local catalog = Catalog.new(locale, root .. "/data/catalog", function(key)
                return ({OS_LANG=language .. "_XX.UTF-8", LANG="de_DE.UTF-8"})[key]
            end)
            assert(catalog.language == language and catalog:text("boot.validation_failed", "invalid_efi"):find("invalid_efi", 1, true))
        end)
    end
    suite:test("unknown translation keys fail explicitly", function()
        local catalog = Catalog.new(locale, root .. "/data/catalog", function() return "en" end)
        suite:reject(function() catalog:text("missing.key") end)
    end)
    suite:test("unsupported language follows explicit locale policy", function()
        local catalog = Catalog.new(locale, root .. "/data/catalog", function() return "xx" end)
        assert(catalog.language == locale.default)
    end)
elseif arg[2] == "applications" then
    local Settings = require("component.application.settings")
    local registry = File.json(root .. "/data/component/application/policy.json")
    for name, policy_entry in pairs(registry) do
        if policy_entry.kind == "settings" then
        suite:test("Lua applies every declared setting for " .. name, function()
            local calls = {}
            local backend = {run=function(_, command, arguments)
                assert(command == "gsettings" and arguments[1] == "set" and #arguments == 4)
                calls[#calls + 1] = table.concat(arguments, "\t")
                return ""
            end}
            assert(Settings.new(root, backend, registry):apply(name) == policy_entry.display)
            local lines = File.list(root .. "/" .. policy_entry.settings)
            assert(#calls == #lines)
            for index, line in ipairs(lines) do assert(calls[index] == "set\t" .. line) end
        end)
        end
    end
    suite:test("unknown application cannot call a native backend", function()
        local backend = {run=function() error("backend_called") end}
        suite:reject(function() Settings.new(root, backend, registry):apply("missing") end)
    end)
    suite:test("native settings errors stop the Lua component", function()
        local count = 0
        local backend = {run=function() count = count + 1; error("native_failure") end}
        suite:reject(function() Settings.new(root, backend, registry):apply("nautilus") end)
        assert(count == 1)
    end)
elseif arg[2] == "publisher" then
    local directory = process:run("temporary", {"-d"}):gsub("\n$", "")
    local destination = directory .. "/hyprland.lua"
    local publisher = Publisher.new(process)
    suite:test("publisher creates complete configuration", function()
        assert(publisher:publish(destination, "first", "600"))
        assert(File.read(destination) == "first")
    end)
    suite:test("publisher preserves the previous complete content", function()
        publisher:publish(destination, "second", "600")
        assert(File.read(destination .. ".bak") == "first")
    end)
    suite:test("repeated publication keeps only one backup", function()
        publisher:publish(destination, "third", "600")
        assert(File.read(destination .. ".bak") == "second" and not io.open(destination .. ".bak.bak"))
    end)
    suite:test("unchanged publication does not replace the file", function()
        assert(publisher:publish(destination, "third", "600") == false)
        assert(File.read(destination .. ".bak") == "second")
    end)
    suite:test("failed validation preserves configuration and backup", function()
        suite:reject(function() publisher:publish(destination, "invalid", "600", function() error("validation_failed") end) end)
        assert(File.read(destination) == "third" and File.read(destination .. ".bak") == "second")
    end)
    suite:test("repeated atomic replacements remain complete", function()
        for index = 1, 100 do
            local content = tostring(index):rep(8192)
            publisher:publish(destination, content, "600")
            assert(File.read(destination) == content)
        end
    end)
    suite:test("concurrent readers never see missing or partial Lua configurations", function()
        local first, second = ("a"):rep(131072), ("b"):rep(131072)
        publisher:publish(destination, first, "600")
        local done = directory .. "/complete"
        local words = {"/usr/bin/lua", root .. "/tests/lua/concurrent_writer.lua", root, destination, done}
        for index, word in ipairs(words) do words[index] = Process.quote(word) end
        local writer = assert(io.popen(table.concat(words, " "), "r"))
        local observations = 0
        local ok, failure = pcall(function()
            local deadline = os.time() + 30
            while true do
                local value = File.read(destination)
                assert(value == first or value == second, "partial_configuration")
                observations = observations + 1
                local signal = io.open(done, "r")
                if signal then assert(signal:close()); break end
                assert(os.time() < deadline, "writer_timeout")
            end
        end)
        local success = writer:close()
        assert(ok, failure)
        assert(success and observations > 0 and File.read(done) == "complete")
        assert(os.remove(done))
    end)
    assert(os.remove(destination)); assert(os.remove(destination .. ".bak")); assert(os.remove(directory))
else
    suite:test("boot retains encryption resume security and root arguments", function()
        local output = menu:render(menu:read(source("/kernel.efi")), "ABCD-1234", policy)
        for _, value in ipairs({"cryptdevice=fixture", "resume_offset=123", "lsm=apparmor", "rootflags=subvol=@"}) do assert(output:find(value, 1, true)) end
    end)
    suite:test("snapshot command lines remain distinct", function()
        local entries = menu:read(source("/kernel.efi", "rootflags=subvol=@") .. "//snapshot\nprotocol: efi\npath: boot():/snapshot.efi\ncmdline: rootflags=subvol=@/.snapshots/24/snapshot\n")
        assert(#entries == 2 and entries[1].cmdline ~= entries[2].cmdline)
    end)
    suite:test("duplicate boot fields are rejected", function() suite:reject(function() menu:read(source("/kernel.efi") .. "path: boot():/other.efi\n") end) end)
    suite:test("parent paths cannot escape the ESP", function() suite:reject(function() menu:read(source("/../kernel.efi")) end) end)
    suite:test("unsupported boot protocols are rejected", function() suite:reject(function() menu:read(source("/kernel.efi"):gsub("protocol: efi", "protocol: linux")) end) end)
    suite:test("invalid digest lengths are rejected", function() suite:reject(function() menu:read(source("/kernel.efi#abc")) end) end)
    suite:test("GRUB strings reject line injection", function() suite:reject(function() Menu.quote("line\nreboot") end) end)
    suite:test("kernel quoted arguments survive unchanged", function()
        local command = 'root=/dev/mapper/root parameter="two words"'
        assert(menu:render(menu:read(source("/kernel.efi", command)), "ABCD-1234", policy):find(command, 1, true))
    end)
    suite:test("GRUB quote escapes apostrophes", function() assert(Menu.quote("a'b") == "'a'\\''b'") end)
    suite:test("fractional menu indexes are rejected", function()
        local altered = {}; for key, value in pairs(policy) do altered[key] = value end
        altered.default = 0.5
        suite:reject(function() menu:render(menu:read(source("/kernel.efi")), "ABCD-1234", altered) end)
    end)
    local directory = process:run("temporary", {"-d"}):gsub("\n$", "")
    local image = directory .. "/kernel.efi"
    local binary = "MZ" .. string.rep("\0", 58) .. string.pack("<I4", 64) .. "PE\0\0" .. string.rep("\0", 64)
    local function write(content)
        local file = assert(io.open(image, "wb")); assert(file:write(content)); assert(file:close())
    end
    write(binary)
    local digest = process:run("digest", {image}):match("^(%x+)")
    suite:test("real PE image and BLAKE digest validate", function()
        assert(#menu:verify(menu:read(source("/kernel.efi#" .. digest)), directory) == 1)
    end)
    suite:test("integrity drift is rejected with valid PE headers", function()
        write(binary .. "changed")
        suite:reject(function() menu:verify(menu:read(source("/kernel.efi#" .. digest)), directory) end)
    end)
    suite:test("non PE images are rejected", function()
        write("invalid")
        suite:reject(function() menu:verify(menu:read(source("/kernel.efi")), directory) end)
    end)
    suite:test("missing EFI images cannot render a verified menu", function()
        suite:reject(function() menu:verify(menu:read(source("/missing.efi")), directory) end)
    end)
    suite:test("empty inventory is rejected", function() suite:reject(function() menu:verify({}, directory) end) end)
    assert(os.remove(image)); assert(os.remove(directory))
end
suite:finish()
