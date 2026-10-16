---
name: configuration-publication
description: Publish watched desktop configurations without missing-file intervals or partially validated content.
---

Stage the complete content on the destination filesystem, validate it before publication, preserve permissions and the prior version, then atomically rename it into place. Never use an installer that unlinks a watched destination before creating its replacement. Do not publish intermediate fragments as complete configurations.

Hyprland consumers require the runtime adapter and included modules to exist before the main configuration is published. Session application must reload through setup and inspect `hyprctl configerrors`; a successful write alone is insufficient. Tests must use isolated HOME and XDG directories and must not connect mocked installation workflows to the real session bus.
