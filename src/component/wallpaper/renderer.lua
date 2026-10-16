local File = require("core.file")
local Json = require("core.json")
local Publisher = require("core.publisher")
local Catalog = require("component.wallpaper.catalog")
local Renderer = {}
Renderer.__index = Renderer

function Renderer.new(root, process, paths, policy, catalog, environment)
    return setmetatable({root=root, process=process, paths=paths, policy=policy, catalog=catalog, getenv=environment or os.getenv}, Renderer)
end

function Renderer:optional(path)
    local handle, failure, code = io.open(path, "rb")
    if not handle then assert(code == 2, failure); return nil end
    local content = assert(handle:read("a")); assert(handle:close())
    return content
end

function Renderer:palette(theme, active)
    local source = self.getenv(self.policy.platformVariable)
    if not source or source == "" then source = self.policy.platformRoot end
    local content
    local candidates = {
        source .. "/" .. self.policy.themes .. "/" .. theme .. "/" .. self.policy.colors,
        self.paths:resolve("config", self.policy.overlay .. "/" .. theme .. "/" .. self.policy.colors)
    }
    if active == theme then candidates[#candidates + 1] = self.paths:resolve("state", self.policy.current .. "/theme/" .. self.policy.colors) end
    for _, path in ipairs(candidates) do content = self:optional(path) or content end
    assert(content, "palette_missing")
    local colors = {}
    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        local key, value = line:match('^%s*([%w_]+)%s*=%s*"(.-)"%s*#?.*$')
        if key then colors[key] = value end
    end
    for _, key in ipairs(self.policy.colorKeys) do
        assert(colors[key] and colors[key]:match("^#%x%x%x%x%x%x$"), "invalid_palette_" .. key)
    end
    return colors
end

function Renderer.geometry(monitors)
    assert(type(monitors) == "table" and #monitors > 0, "invalid_monitors")
    local width, height = 0, 0
    for _, monitor in ipairs(monitors) do
        local w, h, rotation = monitor.width, monitor.height, monitor.transform or 0
        assert(type(w) == "number" and type(h) == "number" and w > 0 and h > 0 and w % 1 == 0 and h % 1 == 0, "invalid_geometry")
        assert(type(rotation) == "number" and rotation % 1 == 0 and rotation >= 0 and rotation <= 7, "invalid_transform")
        if rotation % 2 == 1 then w, h = h, w end
        width, height = math.max(width, w), math.max(height, h)
    end
    return width, height
end

function Renderer:dimensions()
    local ok, monitors = pcall(self.process.run, self.process, "monitors")
    if ok then return self.geometry(Json.decode(monitors)) end
    assert(not self.getenv("WAYLAND_DISPLAY") or self.getenv("WAYLAND_DISPLAY") == "", monitors)
    io.stderr:write(self.catalog:text("wallpaper.deferred"), "\n")
    local width, height = self.policy.defaultGeometry:match("^([1-9]%d*)x([1-9]%d*)$")
    return assert(tonumber(width)), assert(tonumber(height))
end

function Renderer:link(target, destination)
    local parent = assert(destination:match("^(.*)/[^/]+$"))
    self.process:run("directory", {parent})
    local staging = self.process:run("temporary", {"-d", parent .. "/.publish.XXXXXXXX"}):gsub("\n$", "")
    local temporary = staging .. "/link"
    local ok, failure = pcall(function()
        self.process:run("symbolicLink", {target, temporary})
        assert(os.rename(temporary, destination))
    end)
    if not ok then
        local handle = io.open(temporary, "rb")
        if handle then assert(handle:close()); assert(os.remove(temporary)) end
    end
    assert(os.remove(staging))
    assert(ok, failure)
end

function Renderer:render(theme)
    local policy = self.policy
    local current = self.paths:resolve("state", policy.current)
    local active = self:optional(current .. "/theme.name")
    if active then active = active:gsub("%s+$", "") end
    theme = theme or assert(active, "theme_required")
    assert(theme:match("^[a-z0-9][a-z0-9._-]*$") and not theme:find("..", 1, true), "invalid_theme")
    assert(#policy.variants == 1, "single_wallpaper_required")
    local variant = policy.variants[1]
    assert(variant.id:match("^[a-z][a-z-]*$") and (variant.role == "accent" or variant.role == "foreground"), "invalid_wallpaper")
    assert(type(variant.size) == "number" and variant.size > 0 and variant.size <= 1 and type(variant.opacity) == "number" and variant.opacity > 0 and variant.opacity <= 1, "invalid_wallpaper_dimensions")
    assert(variant.gravity == "center" or variant.gravity == "southeast", "invalid_wallpaper_gravity")
    local colors = self:palette(theme, active)
    local width, height = self:dimensions()
    local geometry = ("%dx%d"):format(width, height)
    local logo = self.root .. "/" .. policy.logo
    local output = self.paths:resolve("config", policy.output .. "/" .. theme)
    local image = output .. "/" .. variant.id .. ".png"
    local cache = output .. "/" .. policy.cache
    local fingerprint = Json.encode({logo=self.process:run("digest", {logo}), policy=policy, colors=colors, geometry=geometry})
    self.process:run("directory", {output})
    if self:optional(cache) ~= fingerprint or not self:optional(image) then
        local temporary = self.process:run("temporary", {output .. "/.render.XXXXXXXX.png"}):gsub("\n$", "")
        local minimum = math.min(width, height)
        local padding = variant.gravity == "center" and 0 or math.floor(minimum / policy.paddingDivisor)
        local values = {geometry=geometry, background=colors.background, logo=logo, color=colors[variant.role], opacity=tostring(variant.opacity), side=tostring(math.max(1, math.floor(minimum * variant.size))), gravity=variant.gravity, offset=("+%d+%d"):format(padding, padding), destination=temporary}
        local arguments = {}
        for _, argument in ipairs(policy.renderArguments) do
            arguments[#arguments + 1] = argument:gsub("{([a-z]+)}", function(key) return assert(values[key], "unknown_render_field") end)
        end
        local ok, failure = pcall(function()
            self.process:run("renderWallpaper", arguments)
            assert(#File.read(temporary) > 0, "empty_wallpaper")
            self.process:run("permissions", {policy.mode, temporary})
            assert(os.rename(temporary, image))
        end)
        if not ok then assert(os.remove(temporary)); error(failure) end
        Publisher.new(self.process):publish(cache, fingerprint, policy.mode, nil, false)
    end
    local archive = self.paths:resolve("data", policy.archive .. "/" .. theme)
    Catalog.run(self.root, output, self.paths:resolve("config", policy.chooser .. "/" .. theme), archive, self.root .. "/" .. policy.policyFile)
    if active == theme then
        local stock = current .. "/theme/backgrounds"
        local mode = tonumber(self.process:run("fileMode", {stock}), 16)
        assert(mode and mode & 0xF000 == 0x4000, "non_directory_stock")
        local retired = Catalog.new(self.process, archive)
        for _, path in ipairs(retired:entries(stock)) do retired:retire(path) end
        self:link(image, current .. "/background")
    end
    return image
end

return Renderer
