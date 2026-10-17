# Changelog

This file is the single narrative source for what changed in every release. It is written in prose so that automated documentation checks keep passing and so that every version reads as a short story rather than as an inventory. The command dispatcher reads this same file when it answers the changelog request, which keeps the installed system and the published history consistent with each other.

## Unreleased

Application dispatch, native command delegation, changelog reading, boot assessment and one time GRUB selection now use Lua components with external policy. CLI installation publishes a validated standalone bundle, preserves managed backups and verifies public directory permissions under restrictive umasks. Public documentation is organized in Italian, English and French with an executable completeness check. Remaining shell provisioning and tests are still inventoried as unfinished migration.

## Release v1.8

Settings is a standalone application with five integrated sections, twenty six Hyprland preferences and two native session timers. Its menu descriptions use OS branding, while Resources, Agents and Micro retirement now use Lua components with preserved personal data. Boot recovery gains a standalone GRUB candidate and a verified text only unlock theme with persistent EFI backups. Firmware boot verification remains pending and the complete Lua migration is not yet achieved.

The migration now targets Lua exclusively. Lua owns the boot parser and renderer, native process arguments, JSON and INI handling, message catalogs and atomic publication. Seven desktop application configurations use Lua components with external data. Ruby sources and runtime dependencies are retired, and the previous Bash source remains archived in v1.0.

La pubblicazione delle configurazioni utente è atomica per evitare file Hyprland temporaneamente mancanti. La versione precedente è conservata nell archivio verificabile `v1.0`; la roadmap e quattro nuove skill governano la migrazione modulare Lua. I cataloghi Lua coprono le sei lingue e la generazione GRUB usa un unico percorso verificato anche per sicurezza e snapshot.

Desktop health reconciliation restores the audio effects application, DNS monitor and matching keyboard runtime. HyprMod gains compact adaptive navigation, separate layout policy and uniform symbolic icons while GTK retains native control geometry. Calendar, weather and clock move into normal tiling applications accessible from the menu. Boot assessment uses Lua with integrity checked EFI and snapshot inventory.

The OS command can launch the default browser, graphical editor, file manager and HyprMod without loading the Omarchy runtime. Role policy remains separate from Bash, private browsing requires an explicit desktop action, and read-only launch resolution exposes the chosen desktop entry without opening an application. The dedicated CLI setup scope installs the dispatcher and its catalogs without restarting the desktop.

The Controls menu and its popup panels are retired in favor of HyprMod as a regular tiling window with a dedicated shortcut, keeping the application launcher as the only menu. OS owned configuration migrates from the native directory to `~/.config/os` with a compatibility link preserving native behavior, and the desktop ships the krepo logo wallpaper generated from the active theme palette instead of the stock logo background. Release publication covers stable signed tags only, and image verification compares the full bundled tree against the tagged commit without a marker file.

## Release v1.7

Session menus and Quickshell components now follow the resolved desktop language across the six supported locales, with source indexed catalogues under the session data directory and a singleton that resolves messages, case folded variants and dynamic patterns while keeping application, media and user content untouched. Release publication covers stable signed tags only, with image verification comparing the full bundled tree against the tagged commit without a marker file.

## Release v1.6

ISO downloads now save the verified image and their temporary files in the directory where the helper is invoked, avoiding RAM backed temporary storage. The Bash helper assembles and removes each part in turn to reduce peak disk usage. Release publication waits for a dedicated CI job to compare the bundled configuration and commit marker with the tagged repository, and publishing permissions are restricted to the release job.

## Release v1.5

The upcoming release introduces the os command dispatcher as a new module that mirrors the complete Omarchy command surface while hardening the root handling around it. Session bus resolution and runtime directory detection now happen before delegation so that graphical commands keep working when they are invoked through privilege boundaries. Failure handling follows the fail fast discipline with visible diagnostics instead of silent degradation. Installation ships both the dispatcher and this changelog to the system paths through the privileged pipeline so that repeated setup runs converge on the same result.

## Release v1.4

This release tightened the image pipeline by verifying the bundled configuration before publication and by explaining image content verification in the documentation. It also recorded the contribution and release policy and required immutable releases so that published history stays trustworthy. The changes read as preparation work that made later customization safer rather than as visible desktop features.

## Release v1.3

This release added a PowerShell downloader for release assets and restored the native fastfetch layout with the KMono logo. The downloader made image retrieval practical from non Unix environments while the fastfetch repair kept system information presentation aligned with the chosen identity.

## Release v1.2

This release enforced prose over Markdown lists in documentation through an automated test and removed the KMono wordmark from the ASCII logo. The two changes belonged together because the branding simplification and the documentation discipline both reduced visual noise across the project.

## Release v1.1

This release applied the KMono identity to desktop defaults and converted core documentation and the documentation index to prose. It switched the bootloader to text GRUB with snapshot recovery and generalized ISO component branding with clearer installation and verification guidance. It added automatic DNS resolver failover and repaired release mechanics by passing the release tag to the build step, by keeping the custom version in release titles, by splitting release assets below the upload limit, and by providing an empty pull request template. A routine supply chain maintenance update accompanied the functional work.

## Release v1.0

The initial release gathered the full hardening and desktop provisioning pipeline into a publishable state. It imported the hardening pipeline with battery charge limits behind a capability probe and fail fast rules across every subproject. It covered provisioning through privilege escalation with user session forwarding and organized application configuration under a single root. It integrated graphical applications with native desktop themes through flattened surfaces and smooth transitions and restored the native Arch Linux system identity. It built autonomous distribution and release tooling around the official Arch Linux kernel with host networking and careful package metadata handling. It automated security scanning and dependency remediation and refined the desktop through EasyEffects tuning and bar layout work. It grouped components under modules with fontconfig filtering for web fonts and introduced the ISO customizer with centralized documentation before publishing Omarchy Custom releases.
