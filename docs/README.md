# Security and desktop roadmap

This document records the security and desktop audit baseline from October 13, 2026. The live-state freeze applied during that audit; it is not a current deployment restriction. Later user-authorized changes are applied through `make setup`. The historical observations below do not describe the current package inventory or desktop configuration.

No system can be guaranteed immune to compromise or injection. Each sprint must define its trust boundary, measurable acceptance criteria, compatibility checks and recovery procedure. Free GitHub automation scans published revisions and pull requests; it does not continuously certify installed packages or unpublished local changes.

## Baseline

Read-only observations on 2026-10-13: OS verification passed 137 checks with six privileged groups skipped; compatibility passed 85 checks with one privileged Polkit warning. UFW, auditd, fail2ban, USBGuard, AppArmor, NetworkManager and Polkit were active. SSH was inactive. Secure Boot was disabled, and the root device was mapped through encrypted storage with Btrfs. These observations are evidence of specific checks, not a security certification.

Hyprland reported no configuration errors and `misc:size_limits_tiled=false`. All 20 observed desktop configuration files, the package inventory and seven service states matched the initial baseline after the audit. Hook boundary tests passed 19 checks and idempotency tests passed 18. Native interactive UI testing remains pending.

Desktop manifest fingerprint: `cbe3b671ea633afe222d92bc07ae80ac1afb43f3db96c58c2fe362f463288831`.

Package inventory fingerprint: `33c1ded113f9ab107ae15222a0f7a0ec066d7994683596fa365867e8e42fc2fc`.

Detailed manifests were stored temporarily under `/tmp/os-baseline.8uINio`; they must not be treated as durable recovery artifacts. GitHub PRs 65 and 66 enabled free automation and updated CI Semgrep to 1.180.0. They did not install software on this machine. Published scans cover the revisions checked by GitHub, not the live system.

## Security sprints

| Sprint | Work | Acceptance evidence |
| --- | --- | --- |
| S00 | Preserve the baseline and live-state freeze | Configuration, packages and services remain unchanged |
| S01 | Reconcile local, published and installed identities | Reviewed scope and signed PR with required checks |
| S02 | Map assets and trust boundaries | Explicit root, user, network, AUR and plugin boundaries |
| S03 | Audit shell injection paths | Hostile arguments cannot become commands; first failure remains visible |
| S04 | Harden privileged environments and logging | Pinned executable paths; secrets excluded from output |
| S05 | Audit filesystem and symlink boundaries | Adversarial fixtures cannot redirect privileged writes |
| S06 | Review AUR builds and supply chains | User-only builds, reviewed sources and verified artifacts |
| S07 | Review network exposure | Effective listeners correlated with firewall rules |
| S08 | Review AppArmor enforcement | Required profiles enforced without desktop regressions |
| S09 | Review PAM and authentication | Login, unlocking and recovery remain functional |
| S10 | Review service isolation | Sandboxing verified without breaking desktop services |
| S11 | Review boot and recovery | Firmware, encryption and recovery verified before changes |
| S12 | Review dependency and package vulnerability coverage | Published and installed inventories tracked separately |
| S13 | Improve drift and incident detection | Alerts identify actionable evidence without unsafe automatic fixes |
| S14 | Run isolated adversarial and release checks | Rollback rehearsed; compatibility and security checks pass |

## Desktop sprints

| Sprint | Work | Acceptance evidence |
| --- | --- | --- |
| U00 | Capture the protected desktop baseline | Actual monitor geometry and configuration fingerprints |
| U01 | Refine the offline prototype | No network dependencies or live configuration writes |
| U02 | Audit exact palette propagation | GTK, terminals and editors use the selected theme |
| U03 | Refine Nautilus sidebar | Clear selection, compact spacing and usable navigation |
| U04 | Refine native file pickers | Keyboard and mouse operation remain functional |
| U05 | Refine context menus | Readable native menus with consistent palette and geometry |
| U06 | Remove checkbox borders | Clear checked states and accessible hit targets |
| U07 | Bound floating windows | Full usable monitor bounds respected; automatic tiling preserved |
| U08 | Test scaling and multiple monitors | Small screens, fractional scaling and monitor changes covered |
| U09 | Improve keyboard discovery and contrast | Focus and selected states remain distinguishable |
| U10 | Review project editor workflow | Mouse-enabled LazyVim, visible commands and personal config preservation |
| U11 | Validate and release the desktop changes | Native screenshots, compatibility checks and tested recovery |

The [offline GTK prototype](../conf/gtk/preview.html) is an exploratory artifact. It does not change installed GTK behavior. Actual native picker context-menu suppression requires toolkit-level validation; a prototype toggle does not establish that capability.

## Delivery gates

Complete each sprint in a feature branch with scoped review, meaningful tests and a recovery procedure. After user authorization to apply, use the privileged setup pipeline and compare against the relevant baseline. Preserve automatic tiling, the single-lockscreen invariant, audio, networking, authentication, Secret Service and existing swap or hibernation.

The [terminal editor guide](../conf/nvim/README.md) documents the staged LazyVim workflow. Configuration is edited in Lua; mouse support does not create a graphical settings application. Plugin updates and language-tool downloads remain user-level executable supply-chain changes and require review.
