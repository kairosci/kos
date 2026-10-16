---
name: lua-migration
description: Replace OS Ruby and Bash algorithms with tested Lua components and external policy data.
---

Lua is the implementation language for new and replaced OS algorithms. Code belongs in `src/`, domain components in `src/component/`, reusable primitives in `src/core/`, policy and resources in `data/`, and essential bootstrap entry points in `script/`. Do not add Ruby. Existing native application languages are platform interfaces, not an excuse to embed orchestration in QML, shell or configuration files.

Read `docs/roadmap.md` and trace every installed caller before replacing a component. Replace its algorithm and tests together; a directory rename alone is not a migration. Derive runtime values from validated system observations and read policy from data. Shell configuration is read as literal data and never sourced to evaluate arbitrary expressions. Reject unsupported syntax visibly.

`v1.0/source.tar.gz` is the frozen Bash source and must remain inert. Do not discover or run its tests or install its scripts. Retain the existing active provisioning components only until their Lua equivalents have behavioral coverage and installed validation; track remaining replacements explicitly. Do not claim complete Lua migration while active Bash algorithms remain.

Publish watched configurations atomically and validate before publication. Clear Lua startup environment for privileged entry points using the interpreter's native environment isolation. Keep process arguments individually quoted and preserve native command failure statuses. Existing green Bash tests do not establish Lua equivalence. Firmware success requires an actual boot.

The canonical versioned implementation lives in `v2.0/`: paths above are relative to that directory. Root `src`, `data`, `script` and `tests/lua` are single-source links required by retained callers. Audit the entire Git repository from its top level, including `v2.0`, so relocation cannot conceal active Bash. Installed runtime bundles retain their internal `src`, `data` and `script` layout; traverse the repository links explicitly during packaging. CI and SAST scan the canonical versioned paths.

Settings validation and persistence belong to `src/component/settings/`; native QML controls bind directly to NetworkManager, BlueZ and PipeWire. Keep secrets out of process arguments. Validate compositor changes before publication and restore the previous generated module on activation failure. Shared runtime packaging belongs to `src/core/bundle.lua`.
