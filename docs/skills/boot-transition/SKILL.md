---
name: boot-transition
description: Prepare and verify the OS GRUB transition while preserving encrypted boot and snapshot recovery.
---

Read `docs/boot-transition.md` before changing boot provisioning. Inventory the ESP, firmware entries, root, encryption, resume and snapshot command lines. Validate each referenced EFI image and its declared digest before generating the candidate menu. Check generated GRUB syntax before publishing.

Candidate installation must preserve BootOrder and use `grub-install --no-nvram`; create-only firmware registration must not select the candidate. Keep recovery entries available until a real candidate boot and recovery test succeed. Syntax checks and EFI file presence cannot verify firmware execution, unlock, resume or hardware initialization. Record those outcomes separately and leave untested outcomes pending.

The first GRUB hardware trial returned to Limine. Diagnose firmware selection separately from configuration syntax. The standalone candidate uses an embedded ESP UUID lookup; do not treat its generation as successful hardware verification. Plymouth appearance is owned by Lua under `src/component/boot/`, with policy in `data/component/boot/appearance.json`. Preserve the complete ESP before native regeneration. Compare entry image and argument pairs, since snapshots can share an image while selecting different roots. Verify payload artwork and restore previous images on failure.
