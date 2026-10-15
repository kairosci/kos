---
name: os-theming
description: >-
  Manage exact Omarchy palette propagation, GTK themes, Qogir icons and complete desktop previews.
---

# OS Theming

The active OS `colors.toml` is the single palette authority. Never map production colors or light mode through theme names. Validate hexadecimal colors before writing any configuration and preserve unrelated user settings.

`zed-theme` writes the active palette through Zed's native `theme_overrides` settings, using the built-in One Dark and One Light foundations. Local theme files load only at editor startup and must not be used for live theme synchronization. Preview capture uses the same generator with isolated settings, verifies a palette change on the same running Zed process, and pairs it with Nautilus.

`gtk-theme` owns GTK settings and GTK 4 CSS variables for libadwaita. Materia supplies the GTK base; override upstream Adwaita settings after every switch. The dark setup default is applied once, with later explicit user theme choices retained.

`folder-color` generates Qogir folder icons in a user overlay using the exact palette accent; inherit the installed Qogir light or dark family for other icons. `shell-icons` persists this overlay in the OS theme. Keep cursor integration and the Qt xdgdesktop platform theme. Browser machine policies are applied by the packaged privileged helper through setup, never by editing running browser profile databases.

Theme hooks are staged in the repository and installed through setup. Setup and post-update share the same hooks and libraries. App configuration installers run automatically before theming; the retired Micro palette hook and disk and btop hooks are removed during migration.

Preview regeneration applies each real system theme, captures the complete active monitor with wallpaper, shell and sample graphical applications, and restores the original theme, background and workspace on success, failure or interruption. Run it only through `make setup REBUILD_PREVIEWS=1`. Isolate sample application state, select capture windows by their owned process groups and never publish personal windows or browser profiles.

`modules/theme-previews/scripts/lib/theme-preview.sh` owns uniform geometry, RGBA depth 8 and density 72. Preserve stock assets for restore and reapply normalization after package updates. Every theme is passed explicitly.

Generate GTK themes with a palette-derived stable name so a theme switch reloads GTK's native theme provider. GTK 3 palette rules belong in that generated theme rather than a user CSS provider cached at startup. Preserve unrelated user CSS. Libadwaita applications also receive GTK 4 user CSS; already running applications that cache it require reopening before those overrides change.
