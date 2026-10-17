# os command

The Lua dispatcher belongs to `src/component/cli/`, with separate policy and roles under `data/component/cli/`. `script/os` is an essential starter. `os app browser`, `editor`, `files` and `settings` resolve desktop entries and launch UWSM without loading Omarchy. Browser, editor and files follow XDG defaults; settings identifies the unified Settings app. `os app --resolve settings` reports the result without opening a window.

The parser preserves literal arguments, validates declared private actions and respects hidden launchers. Other groups still delegate to the native runtime, preserving arguments and exit status. Session context is filled only when missing and actually available. This does not establish an independent desktop replacement.

`os changelog` reads all history or the requested release, failing visibly when the file or release is absent. `make setup SCOPE=cli` publishes a validated runtime bundle and system and user links while preserving unrelated content. Tests cover isolated XDG profiles, hostile arguments, delegation, exit statuses, idempotency and rejection of invalid runtime sources.
