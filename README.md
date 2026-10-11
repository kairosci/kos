# omaconf

Arch Linux security hardening, debloat and theming automation for Omarchy.

## Overview

omaconf provisions and maintains a hardened Omarchy desktop through native Bash automation and standard system utilities. The pipeline applies kernel and authentication hardening, firewall policy, intrusion prevention tooling, package debloating with persistent defaults, per theme desktop integration and battery health enforcement. Every operation is idempotent and verifiable, and no stage depends on anything Python based.

## Repository Architecture

The repository is organized into functional components under dedicated paths, and each rule has exactly one home. The `scripts/` directory holds the root provisioning pipeline in `scripts/lib/modules/`, shared libraries in `scripts/lib/`, the verifier, the compatibility suite and interactive launchers. The `tests/` directory holds modular suites orchestrated by `tests/run-all.sh`. The `hooks/` directory holds Omarchy desktop integration, split by lifecycle event. All per-application configuration modules live under `conf/<app>/`; each app folder owns its data files and user-scope installer. The `theme-previews/` directory holds preview generation and installation. The `ai/`, `clean/`, `obscure/` and `performance/` directories hold focused sub-projects, and `plugins/` holds the desktop plugin catalog. Operational runbooks live in `.skills/`, workflows are exposed through the `Makefile`, and continuous integration under `.github/workflows/ci.yml` runs syntax checks and the modular suites on every change.

## Execution Workflows

The root setup also installs desktop responsiveness protection through
`92-responsiveness.sh`: earlier OOM intervention for application and background
slices, plus resource priority for the core session. See
[the policy and its limitations](conf/performance/README.md). Existing swap and
hibernation remain intact. No configuration guarantees that a system never hangs.

System operations run through the standard Makefile targets. Running `make setup` executes the full hardening and provisioning pipeline as root. Running `make verify` checks the security posture against the expected kernel, service and package assertions. Running `make test` executes the modular test suite. Running `make hook` installs the desktop theme hooks and the i18n runtime for the current user, while `make icons` forces an immediate color update for the active theme and `make theme` synchronizes folder icons together with editor themes for Zed. Running `make zed`, `make cli` installs an individual configuration module, and `make editors` installs all of them. Running `make lang` lists the supported languages and marks the active one, while `make i18n-status` reports the resolved catalog and message count and `make clean` purges local execution logs.

## Provisioning Modules

`scripts/setup.sh` runs as root, opens a log in append mode, resolves the primary user and sources every stage module in a fixed order. Because each module is sourced rather than executed, a module signals that it has nothing to do by returning instead of exiting, and every module degrades gracefully. The environment and package database stage repairs broken pacman entries and defines the helpers used to reach a real user session. The locale stage derives the locale, the console keymap and the XKB layout from the system timezone through the offline resolver, and never assumes an English default. The debloat stage removes stock packages with a normal then forced fallback, writes the dedicated pin list, merges it into `pacman.conf` without duplicates and installs the per user persistence hooks. The defaults stage installs the retained applications, sets the browser, editor, media player and file manager defaults, patches `mimeapps.list` and registers the Hypr bindings. The theming stage creates the per home hook folder, clears leftover color state, copies the hooks with their executable bits and repairs ownership. The opt in desktop stack stage logs a clean skip and returns unless `OMAQT_URL` is set, so no upstream URL is hardcoded anywhere. The shell plugin stage provisions the desktop plugin layer; Neovim and its Omarchy package are removed by debloat. The remaining stages own the firewall, kernel, authentication, SSH, service isolation, security tooling, hardware power and maintenance concerns.

## Shared Libraries

The `scripts/lib/` directory holds code that more than one component needs. The i18n engine resolves symbolic keys against the active catalog and exposes the message helpers used by scripts, modules and installers. The bootstrap shim is self-contained so hooks and installers keep working when no catalog runtime is reachable, degrading to a minimal English stub. The locale map resolves a locale from a timezone offline, and the help renderer draws the localized target listing. The theme preview library normalizes preview images and maintains their overlay store, and it is the single source of truth for both the setup stage and the update hooks. The user config library owns the three patterns shared by every user scope installer: installing a file, installing content from a stream, and replacing a marked block inside a shell profile.

## Configuration Modules

Each app configuration under `conf/` owns its files and user-scope installer. Configuration installers use the shared user config library. The CLI module installs shared shell helpers and quick cards. Micro merges its settings, installs editor bindings and adds its shell helper. Zed merges its base settings with the Linux overlay, installs the keymap and optional snippets. Micro provides native completion and linting plus project run and build actions, symbol navigation, indentation detection, snippets and EditorConfig support. Zed is the editor for files and projects.

Because every installer routes through the user config library, replacing a managed file keeps a single slot backup instead of an unbounded series of timestamped ones, and a managed shell block is removed and rewritten in place on every run. The result is that repeated installs converge on the same content rather than accumulating state.

## Application Keybindings

Omarchy's Super shortcuts remain owned by Hyprland. In the apps, Ctrl+S saves, Ctrl+F searches the current document, Ctrl+C/X/V copy, cut and paste in each app's context, and Ctrl+Q closes the editor or browser. Zed uses the VS Code keymap; Micro receives matching bindings. The private browser shortcut remains on Omarchy's Super+Shift+Alt+B chord and starts Brave Origin in incognito mode.

## Theme Previews

Preview images must all share the same geometry, color depth and density, otherwise the tiled file manager cannot place a scaled preview reliably. The theme preview library enforces a uniform size, an alpha capable color type, a fixed bit depth and a fixed density on every image it manages, and it works for any theme directory it is pointed at rather than for a fixed set of themes. When a preview is resized, the previous version is preserved so the stock asset can be restored, and an overlay that already matches the uniform geometry is left untouched to avoid pointless rewrites. The rebuild script derives the preview placement inside the file manager from the real canvas geometry instead of from hardcoded pixel offsets, so the tile stays proportional if the canvas changes. The apply script can install previews into a user scope or, with its privileged mode, into the shared theme tree while recording which themes genuinely need an overlay.

## Theme and Persistence Hooks

The `hooks/theme-set.d/` directory holds the hooks that react to a theme change: folder colors, shell icon family, Micro colorschemes generated from the shared palette theme, CLI colors and the system monitor restart. Each hook resolves the current theme name from the Omarchy state directory and picks the light or dark family accordingly. The `hooks/pre-refresh-pacman.d/` and `hooks/post-update.d/` directories each hold a single `99-omaconf-persist` hook that re-merges the pins, re-applies the removals, resets the MIME defaults, restores the shared GTK file chooser and Hyprland capture routing, masks the crash watcher and re-normalizes the previews. The update hook runs as root because the package manager requires it, and it sources the shared libraries it needs instead of carrying its own copy.

## Security Posture and Kernel Protections

Kernel security is enforced through a single sysctl drop-in with full address space randomization, restricted kernel pointers, restricted dmesg buffers, disabled unprivileged eBPF execution, restricted ptrace debugging and SysRq limited to emergency sync. Filesystem protection disables setuid core dumps and enforces strict ownership checks on symlinks, hardlinks, FIFOs and regular files in sticky directories. Network protections include reverse path filtering, disabled redirects and source routing, ignored broadcast echo requests and active TCP SYN cookies with TIME WAIT hardening.

## Access Control and System Hardening

Authentication locks accounts after a configured number of consecutive failed attempts through `faillock.conf`, password complexity is required through `pwquality.conf` and core dumps are disabled globally. SSH denies root login and password authentication while enforcing modern ciphers, and the daemon is isolated through systemd drop-ins with strict filesystem and privilege restrictions. The UFW firewall denies incoming traffic by default and allows outgoing. Host tooling integrates AppArmor mandatory access control, auditd logging, fail2ban monitoring, USBGuard device authorization, ClamAV scanning and weekly automated audits.

## Desktop Parity and Debloat Strategy

Theming keeps the system monitor, folder colors, the icon theme and the cursor in sync with the active palette, and generates Micro colorschemes dynamically from the current theme. Nautilus is the default graphical file manager; GTK provides desktop open and save dialogs. The pipeline removes unneeded stock packages and uses Brave Origin as the default browser, Zed as the editor for files and projects, Nautilus as the graphical file manager, a lightweight image viewer, a media player, a document viewer and a console system monitor. No `IgnorePkg` entries are kept in `/etc/pacman.conf` so system and Omarchy updates flow without held packages, and obsolete web application shortcuts are cleaned from the application directories. MIME defaults are registered per user for the retained document, image and video types, and the shell bar gains the media plugin in the right section.

## Regression Prevention

Hardening must never break the desktop. The session bus, the authorization service, the audio stack, the network manager and every display manager must remain reachable and unblocked, and no stage may starve a service of a permission it needs. Lockscreen regressions are treated as first class defects: a session must own exactly one canonical screen locker, PAM authentication must integrate cleanly, idle and sleep triggers must not overlap into a second or frozen blank screen, and USB input devices must stay authorized. Every modification is checked against the compatibility suite and the verifier, and the modular suites run in continuous integration to keep those guarantees honest.

## Internationalization

Every human-readable string in the scripts, hooks and installers is referenced by a symbolic key resolved through the i18n engine, with catalogs for English, Italian, French, German, Spanish and Portuguese. The active language is resolved from `OMACONF_LANG` first, then the standard `LANGUAGE`, `LC_ALL`, `LC_MESSAGES` and `LANG` variables, and finally the system locale configuration. English is always loaded first and acts as the fallback, and all catalogs must declare exactly the same key set with the same placeholder count so no message can disappear in translation.

## Battery Health and Power Management

Battery longevity enforces a perpetual charging threshold defined in the project configuration. The policy covers supported batteries and persists across boot, suspend and resume, hotplug and system updates through udev rules, a systemd tmpfiles drop-in, a shared sysfs helper and a resume hook. Systems that advertise deep sleep use it to reduce suspend drain, and the setting is never forced on hardware that does not support it.

## Contributing

Follow the project conventions. Commit messages use the Conventional Commits format with a single colon. Scripts run under strict execution options, tolerate no Python dependency, and signal a non-critical failure with a warning instead of suppressing the error. Configuration installers never hardcode a user path. Run the modular suite before proposing a change.

Report security issues through the [private vulnerability reporting policy](SECURITY.md).

The setup pipeline discovers all `conf/*/install.sh` automatically, including Brave Origin, and applies them in the correct user environment. New app configs need their native installer; browser profiles and personal data remain in their native directories. GTK uses Materia and exact Omarchy palette overrides, including libadwaita CSS variables. Folder icons use a generated Qogir accent overlay. First setup defaults to dark mode; subsequent user theme selections are preserved. Yazi and its managed integration are retired.

`make setup REBUILD_PREVIEWS=1` applies every theme to the actual desktop and captures the entire monitor, including wallpaper, bar and sample application windows, before restoring the original theme, background and workspace.

Zed opens project directories directly with `zed --new /path/to/project` or the terminal. Micro remains the terminal alternative. GUI application modules configure native dialogs, media integration and Wayland launchers. GNOME Keyring and Seahorse replace KeePassXC; existing `.kdbx` databases remain untouched.

The `06-os-identity.sh` setup module restores native Arch Linux identity in `/etc/os-release` from the package-owned `/usr/lib/os-release`. The standard identifiers are `NAME="Arch Linux"`, `PRETTY_NAME="Arch Linux"` and `ID=arch`. The original Omarchy `LOGO` and `ANSI_COLOR` values are retained. The original override is preserved under `/var/lib/omaconf/os-identity/`; the root post-update hook reconciles the identity after updates. Desktop icons, themes, configuration and Omarchy packages remain available. Apply through `make setup`.
Main accepts changes only through squash pull requests with signed commits and current CI, SAST and Main PR provenance checks. No bypass actors or direct pushes are permitted. Enable the local guard with `git config core.hooksPath .githooks`; the server ruleset remains authoritative even when local hooks are disabled.
