-- Restore workspace layouts saved by kos-hyprland-workspace-layout-toggle.

local paths = require("default.hypr.paths")
local require_all = require("default.hypr.require_all")

local layouts_dir = paths.state_home .. "/kos/workspace-layouts"

require_all.files(layouts_dir, "kos.workspace-layouts", { reload = true })
