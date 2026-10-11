-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   kos menu keybindings --print

-- To disable every Kos default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.kos"), then add
-- only the bindings you want below:
--   kos_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   kos_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Kos root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Kos menu", "kos-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "kos-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "kos-shell shell toggle kos.emojis")
