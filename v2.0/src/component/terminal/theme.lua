local File = require("core.file")
local Process = require("core.process")
local Theme = {}
Theme.__index = Theme

function Theme.new(root, paths, publisher, policy, environment)
    return setmetatable({root=root, paths=paths, publisher=publisher, policy=policy, getenv=environment or os.getenv}, Theme)
end

function Theme:optional(path)
    local handle, failure, code = io.open(path, "rb")
    if not handle then assert(code == 2, failure); return nil end
    local content = assert(handle:read("a")); assert(handle:close()); return content
end

function Theme:palette()
    local policy = self.policy.theme
    local content = self:optional(self.paths:resolve("state", policy.palette))
    if not content then
        local name = assert(self:optional(self.paths:resolve("state", policy.name)), "terminal_palette_missing")
        name = name:gsub("%s+$", ""):lower():gsub(" ", "-")
        assert(name:match("^[%w_-]+$"), "invalid_terminal_theme_name")
        local platform = self.getenv(policy.platformVariable)
        if not platform or platform == "" then platform = policy.platform end
        assert(platform:sub(1, 1) == "/", "absolute_terminal_platform_required")
        content = File.read(platform .. "/" .. policy.themes .. "/" .. name .. "/" .. policy.colors)
    end
    local colors = {}
    for line in content:gmatch("[^\r\n]+") do
        local key, value = line:match('^%s*([%w_]+)%s*=%s*"(.-)"%s*#?.*$')
        if key then assert(colors[key] == nil, "duplicate_terminal_color"); colors[key] = value end
    end
    for _, key in ipairs(policy.keys) do assert(colors[key] and colors[key]:match("^#%x%x%x%x%x%x$"), "invalid_terminal_color_" .. key) end
    return colors
end

function Theme.render(template, colors)
    return (template:gsub("{([%w_]+)}", function(key) return assert(colors[key], "unknown_terminal_template_color") end))
end

function Theme:plan()
    local policy = self.policy.theme
    local colors = self:palette()
    local environment = self.paths:resolve("config", policy.environment)
    local managed = self.paths:resolve("config", policy.managed)
    local base = self.paths:resolve("config", policy.base)
    assert(not base:find(",", 1, true) and not managed:find(",", 1, true), "ambiguous_terminal_config_path")
    local layers, files = {}, {}
    local existing = self.getenv(policy.configVariable)
    if existing and existing ~= "" then
        assert(not existing:find("[%z\r\n]"), "invalid_terminal_config_environment")
        for path in existing:gmatch("[^,]+") do if path ~= managed then layers[#layers + 1] = path end end
    else
        layers[#layers + 1] = base
        if not self:optional(base) then files[#files + 1] = {root="config", relative=policy.base, path=base, content=policy.emptyConfiguration, mode=policy.mode} end
    end
    layers[#layers + 1] = managed
    local output = Theme.render(File.read(self.root .. "/" .. policy.environmentTemplate), colors)
        .. policy.exportPrefix .. policy.configVariable .. "=" .. Process.quote(table.concat(layers, ",")) .. "\n"
    files[#files + 1] = {root="config", relative=policy.managed, path=managed,
        content=Theme.render(File.read(self.root .. "/" .. policy.configurationTemplate), colors), mode=policy.mode}
    files[#files + 1] = {root="config", relative=policy.environment, path=environment, content=output, mode=policy.privateMode}
    for _, file in ipairs(files) do
        self.paths:guardDirectory(self.publisher.process, self.paths:resolve(file.root, ""), assert(file.relative:match("^(.*)/[^/]+$")))
        self.publisher:inspect(file.path); self.publisher:inspect(file.path .. ".bak")
    end
    return files
end

function Theme:apply()
    for _, file in ipairs(self:plan()) do self.publisher:publish(file.path, file.content, file.mode) end
end

return Theme
