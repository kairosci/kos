# Versioned structure

[Italiano](../it/versioned-runtime.md) · [English](versioned-runtime.md) · [Français](../fr/versioned-runtime.md)

`v1.0/` preserves the original Bash archive and immutable checksum at repository level. It is never executable input. `v2.0/` is the sole active project root and remains the container for future releases; releases do not create new source trees.

Lua code lives in `src/core/` and `src/component/`, data in `data/`, essential starters in `script/`, tests in `tests/`, and documentation in `docs/it/`, `docs/en/` and `docs/fr/`. Retained Bash provisioning lives in this same active tree under `scripts/`, `hooks/` and `modules/`. Relocation does not certify Lua migration.

The repository root retains required native Git and GitHub metadata and links for Make, documentation and agents. GitHub needs real workflow files under `.github/workflows/` and Dependabot configuration under `.github/`; replacing these with links would stop discovery. Repository JSON policies live in `v2.0/data/repository/`. Root implementation aliases for `src`, `data`, `script`, `scripts`, `tests`, `modules`, `hooks`, `conf` and `docs` are removed.

`make test` and `make setup` work from both the repository root and `v2.0/`. System changes use only the setup pipeline. Direct commands use the `v2.0/` prefix. Installed bundles retain their internal `src`, `data` and `script` layout.

`v2.0/script/os-lua migration-report` inspects the whole repository, including new files and extensionless starters. `verify-full-lua` keeps failing while retained shell algorithms or legacy components remain. The [roadmap](../it/roadmap.md) records actual progress; green tests for migrated components do not imply full migration.
