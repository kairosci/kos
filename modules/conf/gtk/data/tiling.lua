local Os_modules_conf_gtk_data_tiling_lua = {}
function Os_modules_conf_gtk_data_tiling_lua.run()
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

hl.curve("osSmooth", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1 } } })
hl.animation({ leaf = "global", enabled = false })
for _, leaf in ipairs({ "windows", "windowsIn", "windowsOut", "windowsMove", "borderangle", "workspaces", "workspacesIn", "workspacesOut", "specialWorkspace", "specialWorkspaceIn", "specialWorkspaceOut" }) do
  hl.animation({ leaf = leaf, enabled = false })
end
for _, leaf in ipairs({ "border", "fade", "fadeSwitch", "fadeShadow", "fadeGlow", "fadeDim", "fadeDpms", "fadeLayers", "fadePopups", "layers", "layersIn", "layersOut" }) do
  hl.animation({ leaf = leaf, enabled = false })
end
for _, leaf in ipairs({ "fadeIn", "fadeLayersIn", "fadePopupsIn" }) do
  hl.animation({ leaf = leaf, enabled = true, speed = 1.4, bezier = "osSmooth" })
end
for _, leaf in ipairs({ "fadeOut", "fadeLayersOut", "fadePopupsOut" }) do
  hl.animation({ leaf = leaf, enabled = true, speed = 1, bezier = "osSmooth" })
end

o.window(".*", {
  tag = "-default-opacity",
  opacity = "1 1",
  rounding = 0,
  no_shadow = true,
  no_blur = true,
})
o.window({ float = true }, { max_size = { "monitor_w-2", "monitor_h-2" } })
o.window("xdg-desktop-portal-gtk", { center = true, max_size = { "monitor_w-2", "monitor_h-2" } })
o.window({ modal = false, tag = "negative:floating-window" }, { tile = true })

end
return Os_modules_conf_gtk_data_tiling_lua.run()
