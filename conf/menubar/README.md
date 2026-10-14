# Menubar

Setup discovers this user configuration module automatically. It uses Omarchy's native machine-level `shell.toml` overrides for a 34 px horizontal bar and a 36 px vertical bar at the standard font size. Font scaling remains enabled. The bar uses an opaque, flat surface following the current palette and retains its chosen screen edge.

Menu, workspaces and keyboard layout sit on the left; the clock is anchored at the exact center with weather alongside it. Media, indicators, updates, tray, agents and device controls sit on the right. Only existing widgets are moved. Their settings, personal widgets, unrelated TOML tokens and all other shell configuration remain intact. Native file watching applies both files without restarting the shell. Shared user configuration helpers preserve backups.
