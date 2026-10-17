# OS

[Italiano](../../it/root/README.md) · [English](README.md) · [Français](../../fr/root/README.md)

OS configures an existing Arch Linux desktop through repository-owned provisioning. The active installation still requires the Omarchy runtime. Independent Arch functionality is the target, not a completed replacement. Neither installed package names nor a passing legacy suite establish replacement parity.

`v2.0/` is the single active source tree for current and future releases; `v1.0/` is the immutable original archive. Algorithms belong to `src/core/` and `src/component/`, policy and resources to `data/`, essential starters to `script/`, tests to `tests/`, and documentation to `docs/it/`, `docs/en/` and `docs/fr/`. Retained Bash algorithms remain visible in the migration report. Native interface formats such as QML, CSS, desktop entries and systemd units keep their platform formats.

## Installation and operation

Work from the repository root or `v2.0/`. The supported application path is `make setup`, which requests local Polkit authentication and runs the privileged pipeline. Stage changes in the repository first; do not copy fixes directly into the session or system. The full setup reconciles packages, application defaults, themes, authentication, firewall, security tools, hardware policy and the session. Optional destructive or recovery operations remain explicitly selected.

| Command | Purpose |
| --- | --- |
| `make help` | Localized command reference |
| `make test` | Automated repository suites |
| `make verify` | Read-only checks of the applied system |
| `make setup SCOPE=cli` | Install the Lua dispatcher and application roles |
| `make setup SCOPE=lua-applications` | Apply migrated application configurations |
| `make setup SCOPE=settings` | Reconcile the unified Settings application and HyprMod integration |
| `make setup SCOPE=session` | Validate and publish the desktop session |
| `make setup SCOPE=wallpaper` | Reconcile the single palette-derived logo background |
| `make setup SCOPE=performance` | Apply responsiveness and editor resource budgets |
| `make setup SCOPE=keyboard` | Reconcile keyboard backlight policy |
| `make setup SCOPE=boot-assessment` | Record and verify the current boot inventory |

`RUN_MIGRATIONS=1` runs genuine packaged migrations before OS debloat; it never fabricates completion markers. `RESTORE_OMARCHY=1` backs up user configuration before restoring packaged defaults. `RESET_SNAPSHOTS=1` creates and verifies a baseline before retiring older snapshots; snapshot zero, active and default snapshots are preserved. A temporary snapshot root is refused for normal provisioning. Recovery retains backups on persistent home storage.

## Desktop and applications

Super and comma opens one Settings application with desktop, network, Bluetooth, audio and power sections. Its compositor writes are validated, serialized and persisted automatically. Native NetworkManager, BlueZ and PipeWire retain their existing services and profiles. Advanced IP, VPN, enterprise authentication and integrated Bluetooth PIN handling remain incomplete; see [Settings](../settings.md).

Brave Origin is the browser, Zed the graphical editor, packaged LazyVim the terminal editor and Nautilus the file manager with GVFS and File Roller. OnlyOffice handles office documents, Papers PDFs, Loupe images, Celluloid media, Baobab storage analysis and Resources system monitoring. GTK supplies file dialogs; Hyprland supplies screenshot and screen sharing. Required GTK libraries do not imply a GNOME desktop installation. GNOME Keyring remains the Secret Service provider with Seahorse; personal retired credentials and configurations are preserved.

`os app` resolves desktop entries and passes literal argument vectors to UWSM. `os app --resolve settings` returns JSON without launching anything. Private browsing requires the browser's declared desktop action. The dispatcher and installer are Lua components; the essential starter only locates the runtime. Other command groups retain the native runtime contract. See [the command guide](../modules/os/README.md).

The desktop uses one palette-derived logo wallpaper per theme. Superseded chooser images are archived outside the active catalog, preserving packaged originals and personal backgrounds. GTK, icons and Zed follow the active palette. Preview generation captures the complete real monitor with isolated sample windows and restores theme, workspace, wallpaper and notification state on every exit path. Apply through setup, including `REBUILD_PREVIEWS=1` when requested.

## Security and resources

Setup owns kernel sysctl policy, PAM controls, UFW, SSH isolation, AppArmor, auditd, fail2ban, USBGuard and scheduled advisory and malware scanning. Protect core D-Bus, Polkit, NetworkManager, display manager, audio and the single canonical locker. The host audit records detections for review; it does not automatically remove files or certify absence of malware or vulnerabilities. See the [security policy](SECURITY.md).

Responsiveness policy monitors application and background slices, preserves swap and hibernation and protects the session without restarting desktop or audio services. Adaptive build and editor budgets reduce concurrency under limited resources. OOM intervention can terminate an application scope and lose unsaved work; no policy guarantees that arbitrary workloads never exhaust memory or hang. See [performance](../performance.md).

Battery charging and keyboard brightness are capability-probed and verified by hardware readback. Unsupported firmware is reported explicitly instead of claiming enforcement. Sleep and resume preserve the native locker and backlight shutdown ordering.

## Boot and Arch independence

Boot assessment validates EFI image integrity and preserves encryption, per-snapshot roots, security arguments and hibernation resume. GRUB is a separate trial candidate; a failed earlier trial returned to Limine. The standalone candidate is prepared with an explicit ESP UUID, while permanent firmware order and recovery remain preserved. Plymouth text appearance is checked in current images. Firmware execution, unlock, suspend and recovery still require real hardware trials; no automatic reboot occurs. See [boot transition](../boot-transition.md) and [Arch migration](../arch-migration.md).

## Development and releases

All changes originate on feature branches and enter `main` through signed, checked, squash-only pull requests. Required CI and security checks run against the current base with no bypass. Conventional Commit titles and empty PR and merge descriptions follow repository policy. Published tags, metadata and assets are immutable; corrections use a new unused version.

The [ISO guide](../modules/iso/README.md) explains download, checksum verification and limitations. ISO CI compares the complete bundled configuration to the signed source before publishing. It does not boot the image or prove that installation copies OS configuration into the installed root.

`v2.0/script/os-lua migration-report` inventories remaining source algorithms across the whole repository. `verify-full-lua` fails until all retained Bash and Ruby algorithms and legacy components are replaced or legitimately retired. The [architecture](../lua-architecture.md), [language index](../README.md), [contribution policy](CONTRIBUTING.md) and [migration roadmap](../../it/roadmap.md) describe ownership and actual progress.
