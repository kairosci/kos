local animations = {}
local config = {}
local windows = {}
hl = {
    config = function(value)
        config = value
    end,
    curve = function(_, value)
        for _, point in ipairs(value.points) do
            assert(point[1] >= 0 and point[1] <= 1)
            assert(point[2] >= 0 and point[2] <= 1)
        end
    end,
    animation = function(value)
        animations[value.leaf] = value
    end,
}
o = {
    window = function(match, rules)
        windows[#windows + 1] = { match = match, rules = rules }
    end,
}
for _, leaf in ipairs({
    "windowsIn",
    "windowsOut",
    "windowsMove",
    "workspacesIn",
    "workspacesOut",
    "specialWorkspaceIn",
    "specialWorkspaceOut",
}) do
    animations[leaf] = { enabled = true, style = "slide" }
end
dofile(arg[1])
assert(config.general.allow_tearing == false)
assert(config.misc == nil or config.misc.size_limits_tiled ~= true)
assert(windows[2].match.float == true)
assert(windows[2].rules.max_size[1] == "monitor_w-2")
assert(windows[2].rules.max_size[2] == "monitor_h-2")
assert(windows[3].match == "xdg-desktop-portal-gtk")
assert(windows[3].rules.center == true)
for _, leaf in ipairs({
    "global",
    "windows",
    "windowsIn",
    "windowsOut",
    "windowsMove",
    "workspaces",
    "workspacesIn",
    "workspacesOut",
    "specialWorkspace",
    "specialWorkspaceIn",
    "specialWorkspaceOut",
    "borderangle",
}) do
    assert(animations[leaf].enabled == false, leaf)
end
for _, leaf in ipairs({
    "border",
    "fade",
    "fadeSwitch",
    "fadeShadow",
    "fadeGlow",
    "fadeDim",
    "fadeDpms",
    "fadeLayers",
    "fadePopups",
    "layers",
    "layersIn",
    "layersOut",
}) do
    assert(animations[leaf].enabled == false, leaf)
end
for _, leaf in ipairs({ "fadeIn", "fadeOut", "fadeLayersIn", "fadeLayersOut", "fadePopupsIn", "fadePopupsOut" }) do
    assert(animations[leaf].enabled, leaf)
    assert(animations[leaf].speed >= 1 and animations[leaf].speed <= 1.4, leaf)
end
