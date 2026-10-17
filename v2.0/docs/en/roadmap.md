# Lua migration roadmap

The [status ledger](../it/roadmap.md) is the single authority for sprint completion. This guide describes the roadmap in English without keeping a second set of status flags.

Preserve the verified Bash archive under `v1.0/`, then replace algorithms and their tests with Lua components under `v2.0/src/`. Keep commands, locale policy, catalogs, application destinations and rendering policy under `data/`. Essential starters belong under `script/`; platform interface files retain their native formats.

The roadmap covers reusable runtime primitives, encrypted boot assessment and rendering, graphical application configuration, wallpaper, unified Settings, editor resource planning, package provisioning, security, power, maintenance, verification and session integration. Replace installed callers only after behavioral validation. Keep `make setup` as the sole application path.

The Herdr menu and managed Hyprland binding, EasyEffects preset installer and activator, and GTK configuration installer now use Lua application components with dedicated setup scopes. The Italian status ledger records the current inventory.

The final structural sprint removes remaining shell algorithms and legacy layout files after equivalent replacements exist. `migration-report` inventories the whole repository, including new and extensionless files; `verify-full-lua` must fail while active legacy algorithms remain. Moving files or delegating Bash from Lua never counts as completion.

Arch independence requires separate capability evidence, an independent runtime, real cold boot, suspend, encrypted unlock and recovery. Preserve Limine, working kernels and recovery until these trials pass. Runtime tests and package names do not establish hardware parity. Public guides live in it, en and fr; shared operational instructions and licenses retain their canonical source.

Default package provisioning now reads a validated package policy and installs missing official and AUR packages through Lua. The existing setup stage remains the only system application path; optional package groups retain their graceful failure behavior.

The firewall sprint moves UFW policy application and status verification to Lua. Defaults, ports, rule permissions and service state are checked against canonical data, and drift fails explicitly. Other security policies remain to be migrated.

Sysctl policy, kexec lockdown and core dump limits now use a Lua component with external data and idempotent publication. Verification compares persistent files and 19 active values; other security policies remain to be migrated.

Authentication and SSH policies now live in external data applied by Lua components. PAM migration preserves comments and other stack entries, removes conflicting inline options, keeps a one-time backup and rejects unsupported stacks. SSH validates staged files before publication and verifies its three managed files.
