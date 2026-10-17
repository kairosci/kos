# Terminal helpers and themes

`make cli` applies the Lua terminal component through `make setup SCOPE=terminal`.

`src/component/terminal/` owns helper dispatch, palette rendering and installation. Tool guidance is available in six languages under `data/component/terminal/help/`. Policy, shell integration and rendering templates live alongside those dictionaries. The sourced Bash adapter only exposes `helper` to the interactive shell; the theme hook only starts Lua.

The installer preserves personal shell content and permissions, publishes one managed block and archives the retired helper privately. FZF reads validated colors from the actual theme. LazyGit uses its native `LG_CONFIG_FILE` layers: the personal configuration remains intact, with a separate generated palette layer appended once. Explicit configuration lists are preserved. Invalid palettes, redirected backups and incomplete shell blocks fail before replacing the active shell integration.

Run `lua -E tests/lua/run.lua "$PWD" terminal` from `v2.0/` for isolated behavior checks.
