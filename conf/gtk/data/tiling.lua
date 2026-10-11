hl.config({
  general = { gaps_in = 0, gaps_out = 0, border_size = 1, layout = "dwindle", allow_tearing = false },
  decoration = {
    rounding = 0,
    active_opacity = 1,
    inactive_opacity = 1,
    shadow = { enabled = false },
    blur = { enabled = false },
  },
  animations = { enabled = true },
  group = { groupbar = { gradients = false, gradient_rounding = 0 } },
})

hl.curve("kosSmooth", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1 } } })
hl.animation({ leaf = "global", enabled = false })
for _, leaf in ipairs({ "windows", "windowsIn", "windowsOut", "windowsMove", "borderangle", "workspaces", "workspacesIn", "workspacesOut", "specialWorkspace", "specialWorkspaceIn", "specialWorkspaceOut" }) do
  hl.animation({ leaf = leaf, enabled = false })
end
for _, leaf in ipairs({ "border", "fade", "fadeSwitch", "fadeShadow", "fadeGlow", "fadeDim", "fadeDpms", "fadeLayers", "fadePopups", "layers", "layersIn", "layersOut" }) do
  hl.animation({ leaf = leaf, enabled = false })
end
for _, leaf in ipairs({ "fadeIn", "fadeLayersIn", "fadePopupsIn" }) do
  hl.animation({ leaf = leaf, enabled = true, speed = 1.4, bezier = "kosSmooth" })
end
for _, leaf in ipairs({ "fadeOut", "fadeLayersOut", "fadePopupsOut" }) do
  hl.animation({ leaf = leaf, enabled = true, speed = 1, bezier = "kosSmooth" })
end

o.window(".*", {
  tag = "-default-opacity",
  opacity = "1 1",
  rounding = 0,
  no_shadow = true,
  no_blur = true,
})
o.window({ modal = false, tag = "negative:floating-window" }, { tile = true })
