# Lua architecture

[Italiano](../it/lua-architecture.md) · [English](lua-architecture.md) · [Français](../fr/lua-architecture.md)

Paths are relative to the active `v2.0/` tree. `src/main.lua` loads components and passes arguments to `src/component/runtime/application.lua`. Stateful objects use explicit constructors and metatables; pure utilities remain functions.

`src/core/` owns JSON, files, INI, XDG paths, native processes, message catalogs and atomic publication. Domain algorithms live under `src/component/`: boot image validation and GRUB rendering, application configuration, wallpaper rendering and installation, settings persistence and adaptive resource planning.

`data/core/` owns commands, dependencies, locale precedence, paths and runtime composition. `data/component/` owns domain policies and resources; `data/catalog/` contains the six runtime languages. Data is never evaluated through `load`, `loadfile`, `dofile` or shell interpretation. Native YAML, shell and text files may be literal resources. Structural edits require a tested parser for their format.

`script/os-lua` derives its root from its location, reads external bootstrap data and starts Lua with startup environment processing disabled. System changes always pass through `make setup`. Native application interface formats remain native formats.

Retained algorithms in `scripts/`, `hooks/` and `modules/` are pending migration. The immutable `v1.0/` archive is never an executable backend. `migration-report` inventories the entire Git repository and `verify-full-lua` fails while retained algorithms or legacy components remain. Moving files and invoking Bash from Lua do not establish equivalence.

Runtime bundles are immutable. Sources and JSON are validated before the `current` link changes atomically. A manifest also detects removed files. Failed publication preserves the previous bundle and removes staging; identical content reuses the existing bundle. Implementation, live installation and hardware verification are separate outcomes, tracked in the [roadmap](../it/roadmap.md).
