local File = require("core.file")
local EasyEffects = {}
EasyEffects.__index = EasyEffects

function EasyEffects.new(root, paths, publisher, process, catalog, registry, environment)
    return setmetatable({
        root = root,
        paths = paths,
        publisher = publisher,
        process = process,
        catalog = catalog,
        registry = registry,
        getenv = environment or os.getenv,
    }, EasyEffects)
end

local function trim(value)
    return value:gsub("[\r\n]+$", "")
end

function EasyEffects:apply(name)
    local policy = assert(self.registry[name], "unknown_application")
    assert(policy.kind == "audio-preset", "unsupported_audio_preset")
    local installed, status = self.process:capture("pacmanInstalled")
    assert(status == 0, "package_query_failed")
    local packages = {}
    for package in installed:gmatch("[^\r\n]+") do
        packages[package] = true
    end
    for _, package in ipairs(policy.packages) do
        assert(packages[package], "required_package_missing:" .. package)
    end

    local preset = File.read(self.root .. "/" .. policy.source)
    local parsed = require("core.json").decode(preset)
    assert(require("core.json").isArray(parsed.output.plugins_order), "invalid_audio_preset")
    local expected = policy.plugins
    assert(#parsed.output.plugins_order == #expected, "invalid_audio_preset")
    for index, plugin in ipairs(expected) do
        assert(parsed.output.plugins_order[index] == plugin, "invalid_audio_preset")
    end
    local limiter = parsed.output[policy.limiter]
    assert(
        limiter
            and limiter.bypass == false
            and limiter.threshold <= policy.maximumThreshold
            and limiter["gain-boost"] == true,
        "invalid_audio_preset"
    )

    local config = self.paths:resolve("config", "")
    local data = self.paths:resolve("data", "")
    local stateRoot = self.paths:resolve("state", "")
    local state = self.paths:resolve("state", policy.state)
    local directories = {
        { config, policy.database },
        { data, policy.destination:match("^(.*)/[^/]+$") },
        { config, policy.autostart:match("^(.*)/[^/]+$") },
        { stateRoot, policy.state .. "/before-setup" },
    }
    for _, entry in ipairs(directories) do
        self.paths:guardDirectory(self.process, entry[1], entry[2])
    end
    self.process:run("directory", { state .. "/before-setup" })
    self.process:run("permissions", { "700", state })
    self.process:run("permissions", { "700", state .. "/before-setup" })
    local databaseDirectory = self.paths:resolve("config", policy.database)
    local databases, list_status =
        self.process:capture("findFiles", { databaseDirectory, "-maxdepth", "1", "-type", "f", "-print0" })
    assert(list_status == 0 or list_status == 1, "database_inventory_failed")
    for database in databases:gmatch("[^%z]+") do
        local backup = state .. "/before-setup/" .. database:match("([^/]+)$")
        if not self.publisher:inspect(backup) then
            local content = File.read(database)
            self.publisher:publish(backup, content, "600")
        end
    end
    self.publisher:publish(self.paths:resolve("data", policy.destination), preset, "600")
    self.publisher:publish(
        self.paths:resolve("config", policy.autostart),
        File.read(self.root .. "/" .. policy.autostartSource),
        "644"
    )

    local runtime = self.getenv("XDG_RUNTIME_DIR")
    if runtime and self.process:status("isSocket", { runtime .. "/bus" }) == 0 then self:activate(policy, state) end
    return policy.display
end

function EasyEffects:activate(policy, state)
    local function query()
        local value, status = self.process:capture("easyEffects", { "--last-loaded-preset", "output" })
        assert(status == 0, "preset_query_failed")
        return trim(value)
    end
    local previous = query()
    local marker = state .. "/default-applied"
    local previousMarker = self.publisher:inspect(marker)
    if previousMarker and previous ~= policy.preset then return end
    local loaded = self.process:status("easyEffects", { "--load-preset", policy.preset })
    if loaded == 0 and query() == policy.preset then
        self.publisher:publish(marker, policy.preset .. "\n", "600")
        return
    end
    self.process:status("easyEffects", { "--bypass", "1" })
    error("preset_activation_failed:" .. policy.preset)
end

return EasyEffects
