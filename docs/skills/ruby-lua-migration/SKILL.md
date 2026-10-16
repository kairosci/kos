---
name: ruby-lua-migration
description: Migrate OS provisioning components from Bash to Ruby and Lua with measured behavioral equivalence.
---

Use `docs/roadmap.md` to select the next dependency-complete sprint. Ruby owns host orchestration and pure domain services; Lua owns compositor behavior. Implement real objects with state and responsibility rather than renaming functions. Keep executable entry points thin and retain failure status through every caller.

`v1.0/source.tar.gz` is the frozen pre-migration source, not an installed runtime. Verify its SHA256 before extraction into a temporary directory. Do not discover its tests, source its scripts or edit the archive during migration. Document the exact replaced callers, installation paths and test commands before removing active Bash components.

A migrated component is complete only after its installed entry point, translations, repeated application and invalid-input behavior are tested. Existing green Bash tests do not establish Ruby equivalence. Keep remaining work explicit in the roadmap; never mark an entire migration complete from one new parser.
