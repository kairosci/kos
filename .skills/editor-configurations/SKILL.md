---
name: editor-configurations
description: >-
  Procedures for managing Zed, OnlyOffice and Brave Origin configurations in Omarchy.
---

# Editor Configurations

`conf/<app>/` is the single home for application configurations. Each app folder owns its data and exposes one user-scope installer. Every installer uses `scripts/lib/userconf.sh` for atomic installs, backups and marked shell blocks.

## OnlyOffice

OnlyOffice handles word processing, spreadsheets and presentations. Merge its native INI preferences through `userconf.sh`, preserve account data and unrelated preferences, and register office MIME types through `desktop-workflow.sh`. Papers remains the default PDF viewer.

## Zed

Zed is the sole editor for plain text, source files and projects. Nautilus keeps directory MIME handling; open projects with zed --new. Micro and Geany are removed and pinned by debloat; setup removes their managed launchers and helpers while preserving personal configuration. Zed settings use native JSON preferences and keymap. Merge user settings with `jq` when available and retain the documented fallback when it is not.

Apply configurations through setup. `make theme` synchronizes folder icons and Zed colors from the active Omarchy palette.

The setup stage discovers every `conf/*/install.sh` automatically and executes it inside each real user session before theme hooks. A new app config directory must provide an installer using `userconf.sh`; never edit browser profile databases or overwrite active browser preferences. Brave Origin's launcher reads its native flags file, while its existing profiles remain in the standard user config directory.
