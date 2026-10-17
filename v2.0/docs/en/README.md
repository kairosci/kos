# OS documentation

[Italiano](../it/README.md) · [English](README.md) · [Français](../fr/README.md)

`v2.0/` is the active root for current and future releases; `v1.0/` preserves the verifiable original archive. Code, data, tests and documentation stay separate. The [versioned structure](versioned-runtime.md) explains paths and native GitHub exceptions.

[Settings](settings.md) unifies desktop, network, Bluetooth, audio and power in one application. [Responsiveness](performance.md) explains process budgets and OOM protection limits. The [Lua architecture](lua-architecture.md) separates algorithms, data, starters and native interfaces.

The [boot transition](boot-transition.md) preserves encryption and recovery. [Arch migration](arch-migration.md) requires functional parity and hardware trials before retiring Omarchy. The [roadmap](../it/roadmap.md) separates implementation, application and hardware validation; a green test does not establish full migration.

From the repository root or `v2.0/`, `make test` runs the suites and `make verify` checks the current system. `make setup` is the sole system application path; scopes restrict it to the requested domain. Never hot-apply changes through manual copies or service restarts.

Normative agent instructions and skills keep their English authority under `docs/en/`, exposed through links. The [project guidelines](root/AGENTS.md), [security policy](root/SECURITY.md), [module guides](modules/conf/README.md), [ISO guide](modules/iso/README.md) and [skills](skills/) retain technical and historical detail. The original license is not translated or modified.
