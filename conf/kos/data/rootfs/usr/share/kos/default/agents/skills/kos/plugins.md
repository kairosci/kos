# Kos Shell: Bar, Plugins, and Idle

Read this before changing the status bar, notifications, shell plugins,
widgets, or idle/lock behavior.

The bar, notification daemon, settings panel, and assorted overlays all run
inside a single long-running Quickshell process (`kos-shell`).

```
~/.config/kos/shell.json             # User overrides: bar, plugins, idle
~/.config/kos/plugins/<plugin-id>/   # User-owned shell plugins
$KOS_PATH/config/kos/shell.json  # Canonical defaults
```

The shell hot-reloads `shell.json` on save — no restart needed for layout
changes. `idle.screensaver` and `idle.lock` are seconds since user idle began.

**Commands:** `kos restart shell`, `kos refresh shell`

## Bar Layout

Use the `kos bar` group to move and manage widgets:

```bash
kos bar move kos.clock --section right
```

For layout edits beyond what the commands cover, edit the bar configuration
in `~/.config/kos/shell.json`; it hot-reloads on save.

## Customizing Built-In Plugins and Widgets

To customize a built-in bar widget, never edit `$KOS_PATH/shell/plugins/`.
Clone it into the user plugin directory instead:

```bash
kos plugin clone kos.workspaces
# Edit ~/.config/kos/plugins/<username>.workspaces/; saved changes reload automatically.
```

Cloning switches the bar to the cloned copy (e.g. `<username>.workspaces`),
which is yours to edit and survives updates.

Saving a file anywhere under `~/.config/kos/plugins/` reloads plugin code
automatically. If a change somehow fails to apply, force a reload with
`kos-shell shell rescanPlugins`.

## Idle and Lock

Set `idle.screensaver` and `idle.lock` in `~/.config/kos/shell.json`,
in seconds since user idle began. Example: "lock after ten minutes" means
setting `idle.lock` to `600`.
