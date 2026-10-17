local File = require("core.file")
local Blocks = require("core.blocks")
local Bundle = require("core.bundle")
local Namespace = require("core.user_configuration")
local Theme = require("component.terminal.theme")
local Installer = {}
Installer.__index = Installer

function Installer.new(root, paths, publisher, process, policy, environment)
    return setmetatable({
        root = root,
        paths = paths,
        publisher = publisher,
        process = process,
        policy = policy,
        getenv = environment or os.getenv,
    }, Installer)
end

function Installer:install()
    local policy, process = self.policy, self.process
    local rc = self.paths:resolve("home", policy.shell.file)
    local existing, metadata = self.publisher:inspect(rc)
    local mode = metadata and ("%o"):format(metadata & 0xFFF) or policy.shell.mode
    local content = Blocks.merge(
        existing or "",
        policy.shell.first,
        policy.shell.last,
        File.read(self.root .. "/" .. policy.shell.body)
    )
    local legacy = self.paths:resolve("data", policy.legacy)
    local previous = self.publisher:inspect(legacy)
    local theme = Theme.new(self.root, self.paths, self.publisher, policy, self.getenv)
    theme:plan()
    Bundle.new(self.root, process, self.paths, policy):publish()
    Namespace.new(self.paths, process, File.json(self.root .. "/" .. policy.namespace)):migrate()
    local files = theme:plan()
    files[#files + 1] = {
        root = "data",
        relative = policy.adapter.destination,
        path = self.paths:resolve("data", policy.adapter.destination),
        content = File.read(self.root .. "/" .. policy.adapter.source),
        mode = policy.mode,
    }
    files[#files + 1] = {
        root = "config",
        relative = policy.hook.destination,
        path = self.paths:resolve("config", policy.hook.destination),
        content = File.read(self.root .. "/" .. policy.hook.source),
        mode = policy.hook.mode,
    }
    if previous then
        files[#files + 1] = {
            root = "state",
            relative = policy.archive,
            path = self.paths:resolve("state", policy.archive),
            content = previous,
            mode = policy.privateMode,
        }
    end
    for _, file in ipairs(files) do
        self.paths:guardDirectory(
            process,
            self.paths:resolve(file.root, ""),
            assert(file.relative:match("^(.*)/[^/]+$"))
        )
        self.publisher:inspect(file.path)
        self.publisher:inspect(file.path .. ".bak")
    end
    self.publisher:inspect(rc .. ".bak")
    for _, file in ipairs(files) do
        self.publisher:publish(file.path, file.content, file.mode)
    end
    self.publisher:publish(rc, content, mode)
    if previous then assert(os.remove(legacy)) end
    return policy.display
end

return Installer
