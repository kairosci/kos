---
name: editor-configurations
description: >-
  Procedures for managing Neovim, retired Micro, Zed, OnlyOffice and Brave Origin configurations in OS.
---

# Editor Configurations

`modules/conf/<app>/` is the single home for application configurations. Each app folder owns its data and exposes one user-scope installer. Every installer uses `scripts/lib/userconf.sh` for atomic installs, backups and marked shell blocks.

## OnlyOffice

OnlyOffice handles word processing, spreadsheets and presentations. Its migrated policy lives in `data/component/application/onlyoffice/` and the application registry. Merge native INI preferences through `src/core/ini.lua` and publish through `src/core/publisher.lua`, preserving account data, unrelated preferences and private backups. Register office MIME types through `desktop-workflow.sh`. Papers remains the default PDF viewer.

## Zed

Zed is the desktop editor for plain text, source files and projects. Nautilus keeps directory MIME handling; open graphical projects with `zed --new`. Packaged LazyVim is the terminal editor. The retired Micro installer removes its unreliable filemanager plugin and its startup setting while preserving unrelated settings and plugins, without changing the editor environment. `modules/conf/nvim/install.sh` seeds the packaged LazyVim starter, preserves personal files and caches, and owns `EDITOR` and `VISUAL`. Geany remains retired. Zed settings use native JSON preferences and keymap. Merge user settings with `jq` when available and retain the documented fallback when it is not.

Apply configurations through setup. `make theme` synchronizes folder icons and Zed colors from the active OS palette.

The setup stage applies the Lua application registry and then discovers remaining `modules/conf/*/install.sh` installers inside each real user session before theme hooks. Add new application policy to `data/component/application/` and implement new algorithms in `src/component/application/`; do not restore retired Bash installers. Never edit browser profile databases or overwrite active browser preferences. Brave Origin's launcher reads its native flags file, while its existing profiles remain in the standard user config directory.
