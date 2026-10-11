# Theme previews

Run `make setup REBUILD_PREVIEWS=1` to regenerate a preview for every installed system theme through the privileged pipeline.

The capture runner applies each actual Kos theme, waits for its wallpaper and shell transition, opens sample Zed and Nautilus windows on an unused workspace, and captures the complete focused monitor. Application state is isolated from personal sessions. The original theme, background and workspace are restored on completion or failure.

Previews are normalized by `scripts/lib/theme-preview.sh` to uniform geometry, RGBA depth 8 and density 72. Setup installs user overlays and the update hook preserves normalization. Stock previews remain available for restoration.

The capture settings use an isolated keyfile backend so GTK actually resolves the configured icon theme. Generated GTK themes and icon assets remain available to isolated apps without exposing personal configuration. Window size and position are proportional to the focused monitor; no window crops or synthetic compositions are used.

Qogir supplies the complete icon set, with an accent overlay matching each theme and light or dark icons selected from the palette.

Preview regeneration places Zed on the left and Nautilus on the right. Each window fills its half of the monitor work area at the application's native font size; shell reserved areas and monitor scaling are included in the geometry. The complete desktop capture is normalized once to the canonical preview format. Regenerate assets through `make setup REBUILD_PREVIEWS=1` after merging these changes.
