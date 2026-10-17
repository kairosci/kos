local File = require("core.file")
local Json = require("core.json")
local Blocks = require("core.blocks")
local Installer = {}
Installer.__index = Installer

function Installer.new(root, paths, publisher, process, policy, catalog, environment)
    return setmetatable({
        root = root,
        paths = paths,
        publisher = publisher,
        process = process,
        policy = policy,
        catalog = catalog,
        getenv = environment or os.getenv,
    }, Installer)
end

function Installer:install()
    local policy, process = self.policy, self.process
    local native = self.getenv(policy.skeletonVariable)
    if not native or native == "" then native = policy.skeleton end
    assert(native:sub(1, 1) == "/", "absolute_editor_skeleton_required")
    for _, directory in ipairs(policy.guards) do
        self.paths:guardDirectory(
            process,
            "/",
            (self.paths:resolve(directory.root, "") .. directory.path):gsub("^/+", "")
        )
    end
    local config = self.paths:resolve("config", policy.configuration)
    local init = self.publisher:inspect(config .. "/" .. policy.initialization)
    local files = {}
    if not init then
        self.publisher:inspect(native .. "/" .. policy.nativeConfiguration .. "/" .. policy.initialization)
        assert(
            process:status(
                "pathExists",
                { native .. "/" .. policy.nativeConfiguration .. "/" .. policy.initialization }
            ) == 0,
            "packaged_editor_missing"
        )
        for source in
            process
                :run("runtimeFiles", { native .. "/" .. policy.nativeConfiguration, "-type", "f", "-print0" })
                :gmatch("[^%z]+")
        do
            local relative = source:sub(#native + #policy.nativeConfiguration + 3)
            self.paths:guardDirectory(process, config, relative:match("^(.*)/[^/]+$") or "")
            local destination = config .. "/" .. relative
            if not self.publisher:inspect(destination) then
                files[#files + 1] = { path = destination, content = File.read(source), mode = policy.mode }
            end
        end
    end
    local lazy = config .. "/" .. policy.lazyConfiguration
    local hasLazy = self.publisher:inspect(lazy) ~= nil
    if not hasLazy then
        for _, file in ipairs(files) do
            if file.path == lazy then hasLazy = true end
        end
    end
    assert(hasLazy, "incompatible_editor_configuration")
    local cache = self.paths:resolve("data", policy.cache)
    local missingCache = process:status("pathExists", { cache }) == 1
    if missingCache then
        assert(
            process:status("isDirectory", { native .. "/" .. policy.nativeCache }) == 0,
            "packaged_editor_cache_missing"
        )
    end
    local rc = self.paths:resolve("home", policy.shell.file)
    local existing, metadata = self.publisher:inspect(rc)
    local mode = metadata and ("%o"):format(metadata & 0xFFF) or policy.mode
    local body = File.read(self.root .. "/" .. policy.shell.body)
    local shell = Blocks.merge(existing or "", policy.shell.first, policy.shell.last, body)
    local interface = File.json(self.root .. "/" .. policy.interface)
    interface.messages = File.json(self.root .. "/" .. policy.catalog:format(self.catalog.language))
    files[#files + 1] = {
        path = config .. "/" .. policy.interfaceDestination,
        content = Json.encode(interface) .. "\n",
        mode = policy.mode,
    }
    files[#files + 1] = {
        path = config .. "/" .. policy.pluginDestination,
        content = File.read(self.root .. "/" .. policy.plugin),
        mode = policy.mode,
    }
    files[#files + 1] = { path = rc, content = shell, mode = mode }
    for _, file in ipairs(files) do
        self.publisher:inspect(file.path)
        self.publisher:inspect(file.path .. ".bak")
    end
    local stage
    if missingCache then
        local parent = assert(cache:match("^(.*)/[^/]+$"))
        process:run("directory", { parent })
        stage = process:run("temporary", { "-d", parent .. policy.cacheStage }):gsub("\n$", "")
    end
    local ok, failure = pcall(function()
        if stage then
            process:run("copyTree", { native .. "/" .. policy.nativeCache, stage .. "/" .. policy.cachePayload })
        end
        for index = 1, #files - 1 do
            local file = files[index]
            self.publisher:publish(file.path, file.content, file.mode)
        end
        if stage then
            assert(
                process:status("pathExists", { cache }) == 1 and process:status("isLink", { cache }) == 1,
                "editor_cache_changed"
            )
            assert(os.rename(stage .. "/" .. policy.cachePayload, cache))
        end
        self.publisher:publish(rc, shell, mode)
    end)
    if stage then process:run("removeDirectory", { stage }) end
    assert(ok, failure)
    return policy.display
end

return Installer
