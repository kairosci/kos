---
name: boot-transition
description: Prepare and verify the OS GRUB transition while preserving encrypted boot and snapshot recovery.
---

Read `docs/boot-transition.md` before changing boot provisioning. Inventory the ESP, firmware entries, root, encryption, resume and snapshot command lines. Validate each referenced EFI image and its declared digest before generating the candidate menu. Check generated GRUB syntax before publishing.

Candidate installation must preserve BootOrder and use `grub-install --no-nvram`; create-only firmware registration must not select the candidate. Keep recovery entries available until a real candidate boot and recovery test succeed. Syntax checks and EFI file presence cannot verify firmware execution, unlock, resume or hardware initialization. Record those outcomes separately and leave untested outcomes pending.
