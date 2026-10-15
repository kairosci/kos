---
name: editor-configurations
description: >-
  Procedures for managing Neovim, retired Micro, Zed, OnlyOffice and Brave Origin configurations in OS.
---

# Editor Configurations

`modules/conf/<app>/` is the single home for application configurations. Each app folder owns its data and exposes one user-scope installer. Every installer uses `scripts/lib/userconf.sh` for atomic installs, backups and marked shell blocks.

## OnlyOffice

OnlyOffice handles word processing, spreadsheets and presentations. Merge its native INI preferences through `userconf.sh`, preserve account data and unrelated preferences, and register office MIME types through `desktop-workflow.sh`. Papers remains the default PDF viewer.

## Zed

Zed is the desktop editor for plain text, source files and projects. Nautilus keeps directory MIME handling; open graphical projects with `zed --new`. Packaged LazyVim is the terminal editor. The retired Micro installer removes its unreliable filemanager plugin and its startup setting while preserving unrelated settings and plugins, without changing the editor environment. `modules/conf/nvim/install.sh` seeds the packaged LazyVim starter, preserves personal files and caches, and owns `EDITOR` and `VISUAL`. Geany remains retired. Zed settings use native JSON preferences and keymap. Merge user settings with `jq` when available and retain the documented fallback when it is not.

Apply configurations through setup. `make theme` synchronizes folder icons and Zed colors from the active OS palette.

The setup stage discovers every `modules/conf/*/install.sh` automatically and executes it inside each real user session before theme hooks. A new app config directory must provide an installer using `userconf.sh`; never edit browser profile databases or overwrite active browser preferences. Brave Origin's launcher reads its native flags file, while its existing profiles remain in the standard user config directory.
