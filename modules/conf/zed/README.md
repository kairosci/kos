# zedconf

The theme hook generates a native Zed theme from each active OS palette and selects it while preserving unrelated settings. The editor, panels, selections and syntax colors follow the desktop. Theme previews use the same generator in an isolated configuration.

Native Zed editor configuration installer for OS desktop.

## Overview
Zed is the default editor for files and projects. Open a folder with `zed --new /path/to/project` or the terminal. Micro remains available in the terminal. Configuration uses native Zed preferences for the project tree, Git status, session restoration and terminal.

## Installation
Execute the native installation script in the user environment to copy and merge settings into the XDG configuration path:
`make setup`

## Configuration Architecture
Base editor preferences reside in `data/settings.json` while platform overrides reside in `data/linux/settings.json`. Custom key mappings are stored in `data/keybindings.json` and code snippets reside in `data/snippets/`. The installer preserves the previous configuration in `.bak` files when replacing it.

The active palette generates a single `themes/os.json`. Theme synchronization removes retired per-theme files authored by os while preserving personal themes. Static theme snapshots are no longer stored or installed from the repository.
