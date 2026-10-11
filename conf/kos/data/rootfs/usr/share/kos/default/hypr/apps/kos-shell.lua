-- Window and layer rules for the Kos Quickshell surfaces. The
-- shell-wide bar / menu / popouts are layer-shell.

-- Bar uses smooth compositor layer fade animation.
hl.layer_rule({ match = { namespace = "kos-bar" }, animation = "fade" })

-- Launcher, image selector, emojis, clipboard overlays, and keyboard-driven
-- panels use smooth compositor layer fade animation.
hl.layer_rule({ match = { namespace = "^(kos-menu|kos-image-selector|kos-emojis|kos-clipboard|kos-keyboard-panel)$" }, animation = "fade" })

-- Dev gallery is the main shell workbench; open it maximized like
-- SUPER+ALT+F so component previews have the whole workspace.
o.window({ class = "^org.quickshell$", title = "^Kos shell – dev gallery$" }, { maximize = true })
