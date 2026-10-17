local File = require("core.file")
local Configuration = require("core.user_configuration")
local Plugin = {}
Plugin.__index = Plugin

function Plugin.new(root, paths, publisher, process, registry, environment)
    return setmetatable({
        root = root,
        paths = paths,
        publisher = publisher,
        process = process,
        registry = registry,
        getenv = environment or os.getenv,
    }, Plugin)
end

function Plugin:regular(path)
    assert(self.process:status("isLink", { path }) == 1, "redirected_plugin_payload")
    local mode = assert(tonumber(self.process:run("fileMode", { path }), 16))
    assert(mode & 0xF000 == 0x8000, "nonregular_plugin_payload")
end

function Plugin:apply(name)
    local policy = assert(self.registry[name], "unknown_application")
    assert(policy.kind == "plugin", "invalid_plugin_kind")
    local process, source = self.process, self.root .. "/" .. policy.source
    assert(
        process:status("isLink", { source }) == 1 and process:status("isDirectory", { source }) == 0,
        "invalid_plugin_source"
    )
    local files = {}
    for path in process:run("runtimeFiles", { source, "-mindepth", "1", "-maxdepth", "1", "-print0" }):gmatch("[^%z]+") do
        self:regular(path)
        files[#files + 1] =
            { path = policy.payload .. "/" .. assert(path:match("([^/]+)$")), content = File.read(path) }
    end
    assert(#files > 0, "empty_plugin_source")
    for _, entry in ipairs(policy.files) do
        local path = self.root .. "/" .. entry.source
        self:regular(path)
        files[#files + 1] = { path = entry.destination, content = File.read(path) }
    end
    local manifest = File.json(self.root .. "/" .. policy.manifest)
    local package = File.json(self.root .. "/" .. policy.package)
    assert(manifest.id == policy.identity and manifest.version == package.version, "plugin_metadata_mismatch")
    local runtime = self.getenv(policy.validator.variable)
    if not runtime or runtime == "" then runtime = policy.validator.directory end
    assert(runtime:sub(1, 1) == "/", "absolute_plugin_runtime_required")
    for _, file in ipairs(files) do
        assert(
            file.path ~= "" and file.path:sub(1, 1) ~= "/" and not file.path:find("%z"),
            "invalid_plugin_payload_path"
        )
        for segment in file.path:gmatch("[^/]+") do
            assert(segment ~= "..", "unsafe_plugin_payload_path")
        end
    end
    local stage = process:run("temporary", { "-d" }):gsub("\n$", "")
    local ok, failure = pcall(function()
        for _, file in ipairs(files) do
            self.publisher:publish(stage .. "/" .. file.path, file.content, policy.mode)
        end
        local arguments = { runtime .. "/" .. policy.validator.entry }
        for _, word in ipairs(policy.validator.arguments) do
            arguments[#arguments + 1] = word
        end
        arguments[#arguments + 1] = stage
        process:run("environment", arguments)
        Configuration.new(self.paths, process, File.json(self.root .. "/" .. policy.namespace)):migrate()
        local target = self.paths:resolve("config", policy.target)
        self.paths:guardDirectory(process, self.paths:resolve("config", ""), policy.target)
        for _, file in ipairs(files) do
            local destination = target .. "/" .. file.path
            local parent = file.path:match("^(.*)/[^/]+$")
            if parent then self.paths:guardDirectory(process, target, parent) end
            for _, path in ipairs({ destination, destination .. ".bak" }) do
                assert(process:status("isLink", { path }) == 1, "redirected_plugin_target")
                local exists = process:status("pathExists", { path })
                assert(exists == 0 or exists == 1, "plugin_target_probe_failed")
                if exists == 0 then self:regular(path) end
            end
        end
        for _, file in ipairs(files) do
            self.publisher:publish(target .. "/" .. file.path, file.content, policy.mode)
        end
    end)
    process:run("removeDirectory", { stage })
    assert(ok, failure)
    return policy.display
end

return Plugin
