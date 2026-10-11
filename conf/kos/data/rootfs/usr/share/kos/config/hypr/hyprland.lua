-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Kos's bootstrap keeps path setup out of this user config.
dofile((os.getenv("KOS_PATH") or "/usr/share/kos") .. "/default/hypr/bootstrap.lua")

-- Disable all Kos default bindings. Add your own in hypr/bindings.lua.
-- kos_default_bindings = false
--
-- Or disable only bindings for Kos's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- kos_preinstalled_bindings = false

-- Load Kos defaults.
require("default.hypr.kos")

-- Put your personal overrides in these files. They're loaded after Kos's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })
