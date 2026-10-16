# Standard Arch kernel assessment

Assessment date: 2026-10-16. This is an observation of this workstation, not a general hardware guarantee.

The official Arch `linux` package is the maintained standard kernel choice. It includes Arch configuration and packaging; it is not a locally compiled, unmodified kernel.org tree. A custom upstream build adds responsibility for configuration, security updates, initramfs generation and recovery without establishing better security. Prefer the distribution package and normal full system updates.

The running kernel is `7.2.5-3-omarchy`. The standard `linux` package and modules `7.2.3-arch1-3` are already installed. Limine already has separate EFI images and boot entries for both. Both entries retain the encrypted Btrfs root, resume parameters, AppArmor LSM selection and synchronous initramfs setting. Secure Boot is disabled; changing kernel does not enable it. The effective `/etc/default/limine` explicitly puts `linux-omarchy` first and overrides the packaged ordering.

This Intel workstation uses i915 graphics, iwlwifi networking and NVMe storage, all supported by the standard kernel. No proprietary NVIDIA driver was found. Hardware identification alone does not verify firmware behavior, suspend, hibernation, external displays or encrypted boot. The installed standard kernel is older than the running kernel; selecting it is not an established security upgrade. Package database freshness was not established by a full update.

`arch-audit` reports entries for linux with CVEs from 2020–2021 and no fixed version recorded. Those tracker records do not establish that the installed 7.2 kernel remains affected. Review each applicable advisory against upstream fixes and installed versions. The live verifier also reports missing EasyEffects and an inactive DNS failover monitor; these are separate from kernel selection.

Keep the current kernel, its EFI image and snapshot history during evaluation. First perform a full distribution update through a repository-owned privileged setup stage; do not use a partial package upgrade. Inspect generated EFI images and boot entries before selecting the existing `linux` entry for a trial boot. Confirm encrypted unlock, root mount, graphics, Wi-Fi, audio, external displays, suspend and resume, and hibernation where used. Re-run the live verifier and compatibility suite on that kernel. Only then stage the persistent preference in repository policy and reconcile it through setup, preserving unrelated Limine settings and recovery entries. Do not switch bootloaders just to select a kernel.

The current task does not change the default kernel or remove a fallback. A successful trial boot and hardware checks cannot be performed without a reboot, so a claim that this transition is proven safe would be unsupported.

Sources: [Arch linux package](https://archlinux.org/packages/core/x86_64/linux/), [Arch kernel security records](https://security.archlinux.org/package/linux), [Arch kernel build and parallel installation](https://wiki.archlinux.org/title/Kernel/Arch_build_system).
