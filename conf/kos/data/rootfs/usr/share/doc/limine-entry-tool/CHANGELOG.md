# Changelog

## 1.38.0 - 2026-08-31

### Added

- Support all architectures for which Limine provides UEFI binaries. !63
- **limine-mkinitcpio/dracut**: Allow selecting kernels by package name for initramfs and UKI builds.

### Fixed

- **dracut/mkinitcpio hook**: Detect kernels using the `modules.builtin` file instead of the `pkgbase` file, which is
  not reliably available in ARM-based kernel packages.
- **limine-install**: Preserve command-line arguments for auth-helper so `--allow-downgrade` works correctly.
- 
## 1.37.1 - 2026-07-16

No major changes to limine-entry-tool. This release mainly focuses on the Dracut and mkinitcpio hooks.

### Changed

- Refactored both mkinitcpio and Dracut hook scripts:
    - Split the main rebuild logic into smaller, dedicated functions.
    - Improved code readability and maintainability.
    - Simplified non-UKI initramfs and vmlinuz filenames by removing kernel name suffixes.
    - Added support for generating fallback images for a specific kernel or all kernels.
    - Avoid rewriting identical initramfs and UKI files to reduce unnecessary SSD writes.
    - Check `sbctl` installation state using JSON output instead of parsing console output.

### Fixed

- dracut: Restored the missing Limine deployment step in `limine-update`.

## 1.37.0 - 2026-06-30

### Changed

- Replaced `bootctl --print-esp-path` with simple internal boot partition detection.
- Moved the mutex lock file from `/tmp/` to `/run/lock/` for consistency with the FHS.
- Simplified EFI scanner CLI output.
- Bump GraalVM build tool version.

### Removed

- dracut: Removed the deprecated `dracut-rebuild` script.

### Fixed

- Disabled unnecessary `ENABLE_UKI` warning for Secure Boot UKI builds without blake2 hashes on Limine v12.

## 1.36.0 - 2026-04-29

### Added

- Add a post-hook for Limine v12 that warns when Secure Boot and `ENABLE_ENROLL_LIMINE_CONFIG` are enabled but
  `ENABLE_VERIFICATION=yes` is missing.
- A new config option `AUTH_METHOD` allows selecting a different auth method. If unset, the default is `sudo`
- Implement an auth helper to avoid manually entering auth commands such as `sudo` for each CLI command.

### Changed

- `limine-install`: Extend support to Limine v12 (no config syntax changes required).

## 1.35.1 - 2026-04-25

### Fixed or improved

- Fixed ESP path detection for bootctl output containing multiple lines.
- `dracut/mkinitcpio-hook`: Fix `unable to write to pipe (Broken pipe)` caused by breaking out of the loop before stdin
  is fully drained.
- `limine-scan`: Unicode table rendering when supported.
- Merge stderr into stdout for subprocess output instead of separate streams.

## 1.35.0 - 2026-04-20

### Added

- `--add-kernel` as an alias for `--add`, which is too generic in meaning.
- `--remove-kernel` as an alias for `--remove`, which is too generic.
- `--remove-efi-path` as an alias for `--remove-efi`.
- A new option `--keep-files` for `--remove-*` to preserve all related bootable files instead of deleting them.
- `limine-remove-entry` as an alias for `limine-entry-tool --remove-entry`.

### Changed

- `--remove-entry <entry/sub-entry/...> <position>` removes entries from the boot tree hierarchy by path.<br>
  The `<position>` selects which matching entry is removed.
- `--remove-entry <machine-id> <depth>` removes an OS entry matching the given machine ID at the specified tree level.
- Improved `--help` output for better clarity and readability.
- Simplified OS node lookup in the tree traversal algorithm.

### Deprecated

- `--remove-os` is deprecated in favor of `--remove-entry` and remains functionally equivalent.

### Fixed

- `limine-install`: ensure post-hooks run before exiting.
- Entry names containing macros are resolved to their clean equivalent.
- Removed an unnecessary check for the presence of limine.conf before atomic saving.

## 1.34.1 - 2026-04-13

### Fixed

- Fixed an issue where hook execution was incorrectly aborted by `set -euo pipefail`.

## 1.34.0 - 2026-04-13

### Added

- Pre- / post-hook mechanism allows custom scripts to run before and after kernel management and limine.conf updates.
- Ships with two example hook scripts for boot partition locking/unlocking, disabled by default.
- `SKIP_LIMINE_VERSION_CHECK=yes` bypasses Limine major version validation (useful for testing custom Limine). It
  requires `LIMINE_BINARY_PATH` to point to a custom Limine binary.

### Changed

- Updated Limine config doc link following the Limine repo move from Codeberg to GitHub.
- Simplified `limine-common-function` library script.

### Removed

- Removed duplicate files from dracut/mkinitcpio hook directories, as they are already provided by `limine-entry-tool`.

## 1.33.0_1 - 2026-04-06

No changes to limine-entry-tool, only to the dracut/mkinitcpio-hook

### Removed

- Remove `ensure_enroll_config_for_sb()` as Limine v11.2.1 reverted the config checksum enforcement.

## 1.33.0 - 2026-04-03

### Added

- Add enrollment config check for Limine v11.2.0
    * When Secure Boot is active, warn users and automatically enable config enrollment and Limine fallback.

### Changed

- Use native Files API instead of external commands (cp, mv, rm) for file operations.
- Bump GraalVM build tool and jackson-databind versions.

## 1.32.0 - 2026-03-25

### Changed

- `limine-install`: Extend supported Limine major version to 11 (no config syntax changes required).
- Init: Update default limine.conf template header for Limine v11.

## 1.31.1 - 2026-03-14

### Fixed / Improved

- `limine-scan`: Improve safeguards for renaming custom EFI entry names.<br>
  The default fallback name is used if empty names and escaped characters are invalid.

### Added (feature for mkinitcpio hook)

- `MKINITCPIO_UKI_OPTIONS` for configuring custom mkinitcpio options in UKI builds (e.g., adding a splash screen).

## 1.31.0 - 2026-03-04

### Added

- An option `--tree <depth>` that displays the boot menu as a tree. The default depth is 3 if no depth is specified.
  `limine-list` is an alias for this command.
- `limine-scan`: allows renaming a selected boot entry before adding it to Limine.

### Fixed

- **mkinitcpio/dracut hook:** Skip unnecessary full rebuilds when using extramodules.
  (https://gitlab.com/Zesko/limine-entry-tool/-/merge_requests/60)
- Ensure correct case-sensitive path resolution across filesystems (native Linux and vfat), as required by Limine.
- Ensure correct log ordering when multiple logger processes run concurrently by waiting for each process to finish.

## 1.30.0 - 2026-02-08

### Added

- Support multiple `initrd=` kernel parameters by converting them into Limine module paths for non-UKI entries (e.g.
  microcode images such as `amd-ucode.img` or `intel-ucode.img`).
- Deduplicate kernel parameters originating from `/etc/kernel/cmdline` to fix duplicates caused by bugs in some
  systemd-boot tools before generating Limine boot entries.

### Changed

- Replace `guid()` with `uuid()` to follow the RFC 4122 UUID standard rather than Microsoft-specific GUID naming.

### Fixed

- Fix case handling when parsing entry options from Limine comments.

## 1.29.1 - 2026-02-05

### Fixed

- Adjust GraalVM native-image build flags for different x86_64 CPUs.
- Preserve CLI progress output by streaming bytes instead of lines.

## 1.29.0 - 2026-01-30

### Changed

- Migrated build system from Maven with JVM to Gradle with GraalVM
    * Runs as a native executable, no JRE required.
    * Performance improved by over 2.4x at runtime.

## 1.28.3 - 2026-01-24

### Fixed

- Automatically stop reading `/proc/cmdline` when running inside a chroot environment and default kernel cmdline is not
  present.
- Use `NAME` from `/etc/os-release` if the default `PRETTY_NAME` is missing and `TARGET_OS_NAME` is not set while
  initializing `limine.conf`.
- `limine-mkinitcpio-hook`: the `sd-btrfs-overlayfs` hook ensures that the overlayfs-setup script is added to an
  initramfs if `mkinitcpio` does not add it automatically.

## 1.28.2 - 2026-01-11

### Fixed or improved

- Automatically disable colored log output on terminals that do not support color.
- Automatically disable verification and force copying of bootable files when the required `b2sum` utility is missing.
- Skip file hashing when the `b2sum` utility is not available.
- Improved safeguards for btrfs-overlayfs hooks and added additional logging.
- `limine-scan`: Exit with status code 0 instead of 1 when canceled.

## 1.28.1 - 2026-01-04

### Fixed or improved

- Terminal input reader (`TerminalReader`):
    * Correctly handles UTF-8 characters
    * Avoids busy-looping CPU while waiting for user input
    * Supports the Delete key

## 1.28.0 - 2026-01-02

### Added

- Implemented a `TerminalReader` that supports arrow keys (Up, Down, Right, Left) for user input.
- `limine-scan`: Up/Down arrow keys can be used to select an ID for adding to Limine.

### Changed

- `limine-scan`: Improved table formatting for better readability.

## 1.27.0 - 2025-12-12

### Added

- A `comment: kernel-id=...` option to uniquely identify a kernel entry. Changing the kernel entry name does not matter
  when this option is used.

### Changed

- Updated the link to the Limine configuration documentation from version 9 to 10.
- **dracut/mkinitcpio hook**: Every kernel comment includes "Kernel version: ..." for improved clarity.

### Fixed

- `ENABLE_LIMINE_FALLBACK=no` no longer forces creation of the default fallback when none exists.<br>**New behavior:**
  leaving the option empty (`""`) or commenting it out will now create the default fallback only if it does not already
  exist. (See https://gitlab.com/Zesko/limine-entry-tool/-/merge_requests/59)
- Marked comment lines showing where Limine entries were generated to improve transparency and prevent unintended manual
  edits of auto-generated entries in limine.conf.

## 1.26.1 - 2025-11-27

### Fixed

- `limine-scan`: Added proper exit status codes to indicate success or failure in any terminal.
- `limine-install`: Added MBR validation to prevent duplicate Limine EFI entries when using a legacy MBR disk.
- `limine-enroll-config` and `limine-reset-enroll`: Added root privilege check.
- **dracut/mkinitcpio:** Removed unnecessary messages "Secure Boot is disabled. Signing may not be effective." to avoid
  making users think they need to take action.

## 1.26.0 - 2025-11-08

### Added

- `limine-install`: Ensure Limine fallback is deployed if missing, improving boot reliability.
- `limine-install`: Prevent automatic upgrade of Limine EFI binary when it is newer than supported major version 10,
  ensuring forward compatibility and avoiding configuration breakage in future Limine releases.
- `limine-install`: Add a check for conflicting Limine config files; if any exist, warn users so they can decide whether
  to remove them.

### Changed

- Rename Limine folder in ESP from `/Limine/` to lowercase `/limine/`. This change has no effect on FAT32, which is
  case-insensitive.
- Rename Limine config syntax for compatibility with Limine versions 8, 9, and 10:
    * `efi_chainload` -> `efi`
    * `kernel_cmdline` -> `cmdline`
    * `image_path` -> `path`
    * `kernel_path` -> `path`

## 1.25.3 - 2025-11-03

### Fixed

- `limine-install`: Added `--skip-uefi` flag or `SKIP_UEFI=yes` for certain non-compliant UEFI boards with broken EFI
  implementation (e.g., some MSI UEFI boards):
    * Skips UEFI detection via kernel
    * Skips UEFI registration via `efibootmgr`
    * Sets Limine as the fallback bootloader at `$ESP_PATH/EFI/BOOT/BOOTX64.EFI`, the standard UEFI path for all UEFI
      systems

## 1.25.2 - 2025-10-31

### Fixed

- `limine-install`: Correctly parse eMMC/SD partitions for `efibootmgr` on Chrome OS devices.

## 1.25.1 - 2025-10-31

### Fixed and improved

- `limine-install`: No longer requires `ENABLE_LIMINE_FALLBACK` or `FIND_BOOTLOADERS` to be set.
- `limine-install`: `--help` can be run without root.
- `limine-install`: Check for `efibootmgr` before attempting to add a Limine UEFI entry.
- `limine-install`: Validate GPT UUID format (expect 36‑char).
- `limine-install`: Show a clear warning when adding a UEFI entry fails because NVRAM may be full.

## 1.25.0 - 2025-10-26

### Added

- `limine-install --fallback` option to make Limine the default fallback bootloader.

### Changed

- Format shell scripts using shfmt.

### Fixed

- `limine-scan` no longer adds a boot entry to Limine when an unsupported filesystem is detected on the boot partition.

## 1.24.0-3 - 2025-10-03

No changes for **limine-entry-tool**, but updates for **limine-mkinitcpio** and **limine-dracut**.

### Changed

- **mkinitcpio:** `sd-btrfs-overlayfs` hook no longer requires the `base` hook.
- **dracut/mkinitcpio:** added `logger` support in overlayfs setup to report errors at the correct log level.
- **mkinitcpio:** refactored `btrfs-overlayfs` hook for better reliability with BusyBox hooks:
    - Replaced `blkid` with `findmnt`
    - Removed duplicate `btrfsck`, since `btrfs check` is already included.

## 1.24.0-2 - 2025-09-28

No changes for **limine-entry-tool**, but updates for **limine-mkinitcpio** and **limine-dracut**.

### Added

- **mkinitcpio:** `sd-btrfs-overlayfs` hook now compatible with systemd hooks.
- **dracut:** overlayfs module logs actions.

### Changed

- **dracut & mkinitcpio:** Use sbctl success messages instead of custom messages.

### Removed

- **mkinitcpio:** Disabled `sb_sign()` call for UKI, already handled by `sbctl` hook.

## 1.24.0 - 2025-09-18

### Added

- Support for custom UKI file prefix via `CUSTOM_UKI_NAME` config option
    - Allows using a shorter, user-defined prefix instead of the default `machine-id`
    - Only lowercase letters (`a–z`) and digits (`0–9`) are allowed
    - Invalid or unset name fall back to `machine-id`

## 1.23.0 - 2025-09-12

### Added

- `QUIET_MODE=yes|no` option to hide green success messages.
- Added safeguards to the dracut and mkinitcpio pacman hooks:
    * Skip initramfs or UKI build if `limine-entry-tool --get-cmdline` fails.
    * Move a newly generated temporary initramfs to the boot partition only after a successful build.  
      If the build fails, the move is skipped to prevent overwriting critical boot files and avoid hash mismatches.
- Improved safety checks in Utility file operations to prevent accidental or unsafe actions.

### Changed

- Improved the `let-check-java` helper script for better readability.
- Shortened info messages by removing the word "successfully".

## 1.22.1 - 2025-09-02

### Fixed

- Corrected `--get-cmdline` handling to use only the last line as kernel cmdline, preventing invalid output.
- limine-mkinitcpio-install: replaced incorrect `BOOT_PATH` with `ESP_PATH`
- Updated a link: Limine repo has been moved from GitHub to Codeberg.

## 1.22.0 - 2025-08-31

### Added

- New safeguards:
    * Skip processing if kernel name is empty
    * Skip processing if machine-id is invalid
    * Dracut and mkinitcpio hook: do not add a kernel to Limine if initramfs creation fails
    * Dracut and mkinitcpio hook: support `kernel-modules-hook` to safely preserve a kernel in case of upgrade failure
      or power outage

### Changed

- Enhanced pacman hooks (Dracut and mkinitcpio) to handle kernel upgrade failures more safely:
    1. Track kernels marked for removal during an upgrade
    2. Preserve Limine kernel entries on upgrade failure
    3. Clean up Limine boot entries for kernels that no longer exist after a kernel upgrade

### Fixed

- Prevented incorrect kernel matches by adding a path separator to ensure kernel names are matched exactly in paths

## 1.21.0 - 2025-08-24

### Added

- **Code:** Implemented `LimineEntry` for clearer node-to-entry mapping in Limine Manager.

### Changed

- Dracut: refactored `snapshot-overlay.sh` to improve readability.

### Removed

- `limine-install` with `FIND_BOOTLOADERS=yes` no longer uses `--remove-efi`.
- Dropped the pointless `no-cmdline-overwrite` comment option for kernel entries in `limine.conf`.

### Fixed

- `limine-scan` adds `limine-enroll-config` to automatically enroll the Limine config when enabled.

## 1.20.3 - 2025-08-12

### Fixed

- Improved Limine binary version detection:
    - Added a fallback method for cases where the `strings` utility is unavailable, ensuring `limine-install` can still
      run successfully without it.
    - Changed the warning to an info message about a detected Limine downgrade.

- Fixed `--remove-efi` to check for `boot():` instead of `boot` to avoid unintentionally removing EFI entries when their
  file path contain the word "boot".

## 1.20.2 - 2025-08-09

### Fixed

- Removed the `BACKUP_THRESHOLD is deprecated` warning to reduce confusion. Note: `BACKUP_THRESHOLD` is no longer used.

## 1.20.1 - 2025-08-04

### Fixed

- Avoid removing escaped quotes in kernel cmdline values. (#2)

## 1.20.0 - 2025-08-03

### Added

- Version comparison logic in `limine-install` to prevent unintended Limine downgrades.
- New `--allow-downgrade` (`-d`) option in limine-install to explicitly allow downgrades.

## 1.19.1 - 2025-07-25

### Fixed

- Prevented auto deployment of x86_64 EFI files on non-x86_64 systems by adding architecture detection.
- On systemd-free distributions, automatically generate a machine-ID if missing, instead of aborting process.
- Switched from the Limine protocol to the Linux protocol on ARM- or RISC-V-based systems.
- Renamed config option `BACKUP_THRESHOLD` to `CONFIG_BACKUP_THRESHOLD` to avoid confusion, as BACKUP is too general.

## 1.19.0 - 2025-07-06

### Added

- Added parallel Blake2 hashing with integrity checks to detect faulty RAM or CPU.
- Dracut: Added `--reproducible` option to ensure identical initramfs output when inputs remain unchanged.

### Changed

- `limine-reset-enroll` restores Limine binary only if it has changed, avoiding unnecessary disk writes.
- Refactored all console messages into single-line message calls in code.

### Fixed

- Dracut: Resolved a deadlock issue caused by missing `--no-mutex` when switching from initramfs to UKI.

## 1.18.0 - 2025-06-29

### Added

- Drop-in config directories `/etc/limine-entry-tool.d/` and `/usr/share/limine-entry-tool.d/` are supported.
- Implemented `+=` operator for `KERNEL_CMDLINE[x]` to allow parameter appending instead of overwriting.

## 1.17.2 - 2025-06-19

### Fixed

- `--remove-efi` removes matching entries based on the given file path, regardless of whether the file exists.

## 1.17.1 - 2025-06-18

### Fixed

- **mkinitcpio:** Added an informational warning when running `mkinitcpio -P` or `-p` directly, clarifying that
  `mkinitcpio` does not update Limine entries, in order to avoid confusion.
- **dracut:** Marked `dracut-rebuild` as deprecated in favor of `limine-dracut` to avoid conflicts with other packages.
  (The legacy command remains available for now but will be removed in a future release.)

## 1.17.0 - 2025-05-31

### Added

- A new option `--remove-os [OS name]` to remove an OS entry matching a given machine-ID or OS name.
- A new option `--remove-efi [path to EFI file]` to remove an EFI boot entry that matches a specified file path.

## 1.16.4 - 2025-05-18

### Fixed

- Dropped support for loading `/tmp/limine` as an unauthorized temporary config file for security reasons.

## 1.16.3 - 2025-05-16

### Fixed or improved

- Sync cached writes to FAT32 to prevent data loss in case of power failure or forced shutdown.
- Don't overwrite an OS entry with the same name if its machine-ID does not match and no identical OS entry is found.
- Added `ENABLE_LIMINE_FALLBACK` as a clearer alternative to `SET_LIMINE_AS_FALLBACK`.
- Enhanced the description of `ENABLE_ENROLL_LIMINE_CONFIG` to better highlight warnings and risks.

## 1.16.2 - 2025-05-09

### Fixed

- Store the Limine EFI binary backup in a tar archive to stop unintentional signing by `sbctl` or other signature tools.

## 1.16.1 - 2025-04-26

### Fixed or improved

- Replaced unsafe `source` with manual key-value parsing using `read` and `export` when loading config files.
- Switched to using `limine-entry-tool --get-cmdline "kernel name"` instead of the Bash-based `get_kernel_cmdline`
  function, which had several limitations.
- Reduced multiple redundant `mutex_lock` calls to a single call in the initramfs-generator scripts.
- The `limine.conf` generator now sets `hash_mismatch_panic: no` by default to avoid panics on hash mismatches; a
  warning is shown instead.

## 1.16.0 - 2025-04-21

### Added

- Added `limine-scan` as an alias for `limine-entry-tool --scan`.
- Set `default_entry: 2` as the new default during initial `limine.conf` generation.
- Auto-verify all configuration syntax to ensure validity before sourcing the config file.

### Changed

- Refactored multiple inline values (such as paths) into named variables to improve readability and maintainability.

### Fixed

- Fixed registration of the Limine EFI boot entry when its GPT UUID is not present in `efibootmgr`.

## 1.15.0 - 2025-04-16

### Added

- Support for legacy BIOS (with limitations: UKI, auto-deploy of Limine EFI, and enroll-config are disabled)

### Changed

- Disabled automatic EFI registration when running `limine-update`

## 1.14.1 - 2025-04-11

### Fixed

- Corrected the `btrfs-overlayfs` hook for `mkinitcpio`, allowing successful boot using OverlayFS on read-only Btrfs
  snapshots.

## 1.14.0 - 2025-04-11

### Added

- Created a bash script `limine-install` for installing Limine bootloader (EFI x86_64).
- `LIMINE_BINARY_PATH` config option for a custom EFI binary path (default: `/usr/share/limine/BOOTX64.EFI` on Arch
  Linux).
- The new `--remove-all` option allows you to delete multiple kernel entries at once.
- `mkinitcpio` hook support for Arch Linux.

### Removed

- Removed the unnecessary `REGISTER_LIMINE_EFI` option.

## 1.13.0 - 2025-04-03

### Added

- Use `--scan` to list active EFI entries from motherboard and select one to add to Limine.

### Fixed or improved

- Improved error message to clarify that the `<kernel name>` must comply with FAT32 naming rules.
- Bash script: Fixed reading from `findmnt` to get the first line instead of multiple lines.

## 1.12.0 - 2025-03-30

### Removed

- Removed the worse config option `LIMINE_PATH_RESOURCE`. The default `boot()` will always be used in version 1.y.x.

**Note:** A new config option `EXTERNAL_BOOT_PATH` will be introduced in the upcoming major release 2.0.0.

## 1.11.5 - 2025-03-26

### Fixed or improved

- Prevent saving `limine.conf` if no entries are added or removed.
- Implemented an atomic mutex lock to prevent concurrent processes from accessing the same resources on the ESP.
- Added automatic Java version validation. If an unsupported version is detected, an error message is logged.
- Added `JAVA_BIN_PATH` configuration option for specifying a custom Java binary path.

## 1.11.4 - 2025-03-23

### Fixed

- Corrected typos where "limine-snapper-sync" was mistakenly written instead of "limine-entry-tool"
- Fixed incorrect Limine EFI path when using `efibootmgr`

## 1.11.3 - 2025-03-02

### Fixed

- Dracut fallback is disabled by default to prevent excessive space usage, especially when taking multiple snapshots.

## 1.11.2 - 2025-03-02

### Fixed

- Default OS entry now starts with `/+OS name` instead of `/OS name` to prevent confusion when using `default_entry` to
  select a submenu inside the OS entry.

## 1.11.1 - 2025-03-01

### Fixed

- Replaced `stat` with the native Java library to retrieve modified timestamp of a file.

## 1.11.0 - 2025-02-16

### Added

- Support for `path:` in all Limine protocols (requires Limine 8.7.1 or newer)

### Changed

- Preserve old comments when updating the same kernel.
- Renamed `cmdline-overwrite=no` to `no-cmdline-overwrite` in kernel comments.

### Removed

- Removed unnecessary `--no-cmdline-overwrite` argument.

## 1.10.1 - 2025-02-09

### Fixed

- Fixed a typo: Incorrect method name for `cmdline-overwrite` on non-UKI systems.
- Renamed some variables to improve readability.

## 1.10.0 - 2025-01-26

### Added

- Support for the comment `cmdline-overwrite=no` in `$ESP_PATH/limine.conf`, which prevents a kernel cmdline from being
  overwritten by the default cmdline specified in some configuration files.
- `KERNEL_CMDLINE["kernel name"]` allows each kernel entry to have a unique kernel cmdline.
- Added the option `--no-uefi` for Dracut initramfs generation when `DRACUT_UKI=no` is set.

## 1.9.0 - 2025-01-17

### Changed

- Replaced hardcoded version config with dynamic version retrieval.
- Reformatted `pom.xml` file.

### Fixed

- `protocol:` is moved under `comment:` in limine.conf when adding an EFI entry.

## 1.8.1 - 2024-12-27

### Fixed

- Renamed `BACKUP_INTERVAL` to `BACKUP_THRESHOLD` for better clarity.

## 1.8.0 - 2024-12-24

### Added

- Introduced two executables `limine-enroll-config` and `limine-reset-enroll`, which can be invoked by
  limine-snapper-sync.
- Pacman hook: Added support for `sbctl` as an optional dependency. If installed, it automatically signs created UKI.
- Pacman hook: `ENABLE_ENROLL_LIMINE_CONFIG` for automatically enrolling the Limine config into Limine binary to protect
  against modifications to the Limine config. **(Caution!)** This will prevent booting if the Limine config is
  accidentally modified.

### Changed

- Deprecated `/etc/limine-entry-tool.conf`. Use `/etc/default/limine.conf` instead, as it is required by
  `ENABLE_ENROLL_LIMINE_CONFIG` for **limine-dracut-support** only.
- Refactored ConfigReader.java to support reading from multiple configuration files.
- Relocated the Pacman hook script `limine-dracut-functions` to `/usr/lib/limine/limine-common-functions`.

### Removed

- Removed `limine-snapper-sync` from `limine-update`.

### Fixed

- Fixed a typo in the machine-ID regex.
- Addressed an issue where UKI ignores booting into a snapshot when using Secure Boot. **Solution:** Embedded kernel
  cmdline is now removed from UKI, allowing it to read external kernel cmdline during booting.
- Fixed the boot menu order when initializing OS entry.
- Fixed pacman hook script to remove UKI during `dracut-rebuild` when `DRACUT_UKI` is set to `no`.

## 1.7.0 - 2024-12-18

### Added

- Automatic time-based backup of `limine.conf`.
- Support for adding custom comments in kernel boot entries.
- New configuration options: 'BOOT_ORDER' and 'ENABLE_SORT' for controlling kernel entry order and sorting
  alphabetically.
- Added the command option `add-efi` to include an EFI entry at the top level of the Limine tree menu.
- Introduced `--priority X` for configuring boot order specifically for `add-efi`
- For the `limine-dracut-support` package, added `FIND_BOOTLOADERS=yes` to enable automatic detection of existing EFI
  bootloaders and inclusion in Limine.

### Changed

- Renamed some variables for better clarity.
- Improved the algorithm for identifying a machine-ID in boot entry comments.

### Fixed

- Removed all trailing line breaks when loading a line from `/proc/cmdline`.

## 1.6.0 - 2024-12-14

### Added

- For Arch Linux: Added a new config option: `SET_LIMINE_AS_FALLBACK`. Set it to "yes" to make Limine EFI the default
  fallback.

### Changed

- For Arch Linux: Renamed a UKI name to a package-based name for easier EFI registration.
- For Arch Linux: Improved the script for deploying Limine EFI files to the ESP.

### Fixed

- Fixed an issue with case sensitivity where changing a kernel path's case prevented its boot entry from being removed.

## 1.5.0 - 2024-12-11

### Added

- Added validation for kernel names to ensure compatibility with FAT32 file name limitations.

### Fixed

- Resolved mismatches in kernel paths on the ESP caused by Limine requiring case-sensitive paths, while FAT32 is not
  case-sensitive.
- Prevented unnecessary prompts to save the Limine configuration when a Limine entry is removed but not found.

## 1.4.0 - 2024-12-10

### Added

- Added the "--quiet" option to disable success outputs.

### Changed

- Improved the output details of any command.
- Improved the code style of hook scripts for Arch Linux.

### Fixed

- Enhanced EFI path verification.

## 1.3.0 - 2024-12-02

### Added

- For Arch Linux: Automatically register Limine EFI in the motherboard's firmware when reinstalling or updating Limine.

## 1.2.0 - 2024-11-24

### Added

- Support for generating UKIs (Unified Kernel Images) and adding them to Limine boot entries.

## 1.1.1 - 2024-11-10

### Removed

- Remove the hardcoded version in the executable JAR file name.

## 1.1.0 - 2024-09-28

### Added

- `limine-update` is an alias for `dracut-rebuild`.

## 1.0.0 - 2024-09-18

### Added

- Limine-Entry-Tool is finally created
- Changelog
- License
