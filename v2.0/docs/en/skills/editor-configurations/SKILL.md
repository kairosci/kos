---
name: editor-configurations
description: >-
  Procedures for managing Neovim, retired Micro, Zed, OnlyOffice and Brave Origin configurations in OS.
---

# Editor Configurations

Migrated application data lives under `data/component/application/` and algorithms under `src/component/application/` or the owning Lua domain. `modules/conf/<app>/` retains native integration and installers that are still pending replacement. Retained installers use `scripts/lib/userconf.sh` for publication, backups and marked shell blocks.

## OnlyOffice

OnlyOffice handles word processing, spreadsheets and presentations. Its migrated policy lives in `data/component/application/onlyoffice/` and the application registry. Merge native INI preferences through `src/core/ini.lua` and publish through `src/core/publisher.lua`, preserving account data, unrelated preferences and private backups. Register office MIME types through `desktop-workflow.sh`. Papers remains the default PDF viewer.

## Zed

Zed is the desktop editor for plain text, source files and projects. Nautilus keeps directory MIME handling; open graphical projects with `zed --new`. Packaged LazyVim is the terminal editor. The retired Micro installer removes its unreliable filemanager plugin and its startup setting while preserving unrelated settings and plugins, without changing the editor environment. `src/component/editor/neovim/installer.lua` seeds the packaged LazyVim starter, preserves personal files and caches, and owns `EDITOR` and `VISUAL`. Geany remains retired. Zed base and Linux preferences live in `data/component/application/zed/`; adaptive resource policy lives in `data/component/performance/`. Merge settings through Lua and complete generation before invoking the retained watched-file writer. Preserve its inode and avoid rewriting unchanged settings. The keymap and theme adapter remain pending migration.

Apply configurations through setup. `make theme` synchronizes folder icons and Zed colors from the active OS palette.

The setup stage applies the Lua application registry and then discovers remaining `modules/conf/*/install.sh` installers inside each real user session before theme hooks. Add new application policy to `data/component/application/` and implement new algorithms in `src/component/application/`; do not restore retired Bash installers. Never edit browser profile databases or overwrite active browser preferences. Brave Origin's launcher reads its native flags file, while its existing profiles remain in the standard user config directory.
