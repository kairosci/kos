# Entry Automation for Limine Bootloader

### Contents

- [Description](#description)
- [Usage](#usage)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Hooks](#hooks)
- [Features](#features)
- [Planned features](#donate)

## Description

**Entry Automation** (`limine-entry-tool`) provides automatic boot-entry management for the [Limine](https://github.com/Limine-Bootloader/Limine) bootloader on UEFI systems.
<br>It generates, updates, and removes boot entries with periodic `limine.conf` backups.

**Note:** 
Legacy BIOS is also supported, but with limited functionality:

* Automatic EFI binary deployment is disabled.
* UKI auto-generation is disabled.
* Automatic config enrollment is disabled.
* UEFI entry scanning is not supported.

## Usage

<details>
<summary>Install Limine for UEFI</summary>

```shell
limine-install
```
Installs the Limine UEFI bootloader.<br>
It copies the UEFI binary `/usr/share/limine/BOOTX64.EFI` (or as configured via `LIMINE_BINARY_PATH` in `/etc/default/limine`)
to `${ESP_PATH}/EFI/limine/limine_x64.efi` on the boot partition.<br>
If the entry is not already registered in UEFI NVRAM, it will be added automatically.

```shell
limine-install --fallback
```
Sets Limine as the default fallback loader by overwriting `${ESP_PATH}/EFI/BOOT/BOOTX64.EFI` on the boot partition.

</details>

<details>
<summary>Add UEFI boot entries (e.g., dual boot)</summary>

```shell
limine-entry-tool --scan
```
This scans all active UEFI entries from NVRAM, allowing you to select one to add to Limine.

`limine-scan` is an alias for this command.
</details>

<details>
<summary>Display the boot menu</summary>

```shell
limine-entry-tool --tree <max-depth>
```
This displays the boot menu as a tree. If no depth is specified, the default is 3.

`limine-list` is an alias for this command.
</details>

<details>
<summary>Create or update a kernel entry under the OS</summary>

```shell
limine-entry-tool --add-kernel "<kernel name>" "<path to initramfs>" "<path to vmlinuz>" "<suffix>" --comment "<comment>" --quiet
```
**Note:** The `<kernel name>` must follow FAT32 naming rules (letters, digits, `_`,`.`,`-` only).
Spaces or other special characters are not allowed, as the name is used to create a FAT32 directory.

**Examples:**
```shell
# Create a boot entry for "kernel-6.10.1":
limine-entry-tool --add-kernel "kernel-6.10.1" "/tmp/initramfs" "/usr/lib/modules/6.10.1/vmlinuz"

# Create a boot entry for "kernel-6.10.1" with a "-fallback" suffix:
limine-entry-tool --add-kernel "kernel-6.10.1" "/tmp/initramfs-fallback" "/usr/lib/modules/6.10.1/vmlinuz" "-fallback"
```
These create (or update) a kernel boot entry named `kernel-6.10.1` under its OS entry,
and copy the files (`initramfs`,`initramfs-fallback` and `vmlinuz`) to the directory `$ESP_PATH/${machine_id}/kernel-6.10.1/`.

</details>

<details>
<summary>Create or update a UKI entry under the OS</summary>

```shell
limine-entry-tool --add-uki "<kernel name>" "<path to UKI>" --comment "<comment>"  --quiet
```
**Note:** The `<kernel name>` must follow FAT32 naming rules (letters, digits, `_`,`.`,`-` only).
Spaces or other special characters are not allowed, as the name is used to create a FAT32 file.

**Example:**
```sh
limine-entry-tool --add-uki "kernel-6.12.1" "/tmp/uki.img"
```
This creates (or updates) a UKI boot entry named `kernel-6.12.1` under its OS entry,
and copies the UKI file to `$ESP_PATH/EFI/Linux/${machine_id}_kernel-6.12.1.efi`.

</details>

<details>
<summary>Create or update an EFI entry</summary>

```shell
limine-entry-tool --add-efi "<EFI entry name>" "<path to EFI loader file>" --comment "<comment>" --priority "<Number>" --overwrite --quiet
```

Options:

- `--priority <Number>`: Set position in the boot order in limine.conf (default: **50**, middle of range)
- `--overwrite`: Overwrite an existing entry

**Example:**
```shell
limine-entry-tool --add-efi "Default fallback loader" "/boot/EFI/BOOT/BOOTX64.EFI" --priority 10
```
This creates or updates an EFI entry to limine.conf.<br>
If an entry with the same name exists, it will not be overwritten without `--overwrite`.

</details>

<details>
<summary>Remove a kernel entry under the OS</summary>

```shell
limine-entry-tool --remove-kernel "<kernel name>" --keep-files --quiet
# Example:
limine-entry-tool --remove-kernel "kernel-6.10.1-fallback" --keep-files
limine-entry-tool --remove-kernel "kernel-6.10.1"
```
This removes the kernel entry under the OS entry and its directory `$ESP_PATH/${machine_id}/<kernel name>/`.

Options:
- `--keep-files`: Preserve related bootable files instead of deleting them.
</details>

<details>
<summary>Remove a UKI entry under the OS</summary>

```sh
limine-entry-tool --remove-uki "<kernel name>" --quiet
# Example:
limine-entry-tool --remove-uki "kernel-6.10.1"
```
This removes the UKI boot entry under the OS entry and its UKI file at `$ESP_PATH/EFI/Linux/${machine_id}_<kernel name>.efi`.

</details>

<details>
<summary>Remove an entry from the boot menu</summary>

```shell
limine-entry-tool --remove-entry "<entry name/sub-entry name/...>" <position>
# or 
limine-entry-tool --remove-entry "<machine-ID>" <depth>

# Examples:
limine-entry-tool --remove-entry "Arch Linux/Snapshots" 
# Removes the first "Snapshots" entry under the "Arch Linux" OS entry

limine-entry-tool --remove-entry "Windows Boot Manager" 2
# Removes the second "Windows Boot Manager" at the top level of the boot menu

limine-entry-tool --remove-entry "d647abee5e264f469d7a38b751d9d1db"
# Removes an OS entry matching the machine ID at the top level of the boot menu
```
Removes a boot menu entry by path or an OS entry matching a machine ID.<br>
Machine ID comes from the file `/etc/machine-id`

`limine-remove-entry` is an alias for this command.

**Default:** `<position>` and `<depth>` default to `1` if not specified.

**Behavior:**
* `<position>` is a match index that controls which matching entry is removed in path mode.
* If `<position>` is 0, all matching entries are removed (path-based mode only).
* `<depth>` defines the tree level where the machine ID is searched for.

**Note:** 
* This does not delete any related bootable files.
</details>

<details>
<summary>Remove an EFI entry</summary>

```shell
limine-entry-tool --remove-efi-path "<path to an EFI file>" --keep-files
# Example:
limine-entry-tool --remove-efi-path "/boot/EFI/BOOT/BOOTX64.EFI"
```

This removes EFI boot entries matching the specified EFI file path.<br>

The old alias `--remove-efi` is equivalent to `--remove-efi-path`

Options:
- `--keep-files`: Preserve related bootable files instead of deleting them.

</details>

## Requirements

* Limine version **8** or newer
* A FAT32 boot partition with at least 1 GiB of free space
* Standard `coreutils` and `util-linux`
* `bash`, `grep` and `tar` must be installed
* `efibootmgr` for UEFI boot entry registration (but not required on legacy BIOS systems)
* `gradle` and GraalVM 25 (build-time only)

## Installation

**Note:**<br>

This tool generates boot entries only at `$ESP_PATH/limine.conf` and does not touch any other Limine config locations.
If you intend to use `$ESP_PATH/limine.conf` as your primary boot configuration,
remove any alternative Limine config files to prevent them from overriding the boot entries in the Limine boot menu.

<details>
<summary>Some UEFI motherboards (e.g. certain MSI models) may not be fully compatible</summary>

Some motherboards implement EFI in a non-standard or broken way.
This can prevent UEFI tools like `efibootmgr` or kernel-based UEFI detection from working correctly.<br>

**How to fix:**<br>

**Step 1:** Skip UEFI detection and install Limine as the default fallback bootloader:
```sh
limine-install --skip-uefi --fallback
```
**Step 2:** (Optional) Make it permanent, create or edit `/etc/default/limine` and add:
```ini
SKIP_UEFI=yes
ENABLE_LIMINE_FALLBACK=yes
```
**Step 3:** Adjust BIOS boot order<br>
Reboot your system, enter the BIOS/UEFI setup, and change the boot order to select the disk or partition where Limine is installed.
</details>

### Arch Linux

<details>
<summary>Easy setup</summary>

1. Install one of the following packages:
   * [limine-dracut-support](https://aur.archlinux.org/packages/limine-dracut-support/) for Dracut
   * [limine-mkinitcpio-hook](https://aur.archlinux.org/packages/limine-mkinitcpio-hook/) for mkinitcpio <br/>
These packages provide hooks to automatically manage kernel installation and removal using `limine-entry-tool`.

2. If your boot partition is not detected, create or edit `/etc/default/limine` and set `ESP_PATH=` to your FAT32 partition.
   Then run `limine-install` to verify the setup.

3. Ensure all required kernel parameters are set in `/etc/kernel/cmdline`.<br>
(If unsure which kernel parameters to use, copy them from `cat /proc/cmdline` but make sure you are running on your installed system, not from a live ISO environment.)

4. (Optional) Set Limine as the default fallback bootloader in case UEFI boot entries stored in NVRAM are lost or wiped (due to firmware or BIOS updates).
    ```bash
    limine-install --fallback
    ```
5. Regenerate initramfs or UKIs and update kernel boot entries:
    ```bash
    limine-update
    ```
6. (Optional) Detect existing UEFI boot entries (for dual-boot setups):
    ```bash
    limine-scan
    ```

**Note:**
* On UEFI x86_64 systems, Limine binary is automatically deployed during updates or reinstallation.
* On legacy BIOS systems, you must manually copy an appropriate Limine binary to your boot partition.
Follow the instructions: [Limine – BIOS systems](https://wiki.archlinux.org/title/Limine#BIOS_systems_with_MBR)

</details>

**or**

<details>
<summary>Manual setup (for advanced users)</summary>

1. Install `limine-entry-tool` from [AUR](https://aur.archlinux.org/packages/limine-entry-tool/).<br/>
This tool provides full control, but does not include automatic kernel & initramfs handling.
1. Optionally copy default configuration from `/etc/limine-entry-tool.conf` to `/etc/default/limine`
1. Ensure all required kernel parameters are set in `/etc/kernel/cmdline`
1. Install an initramfs tool of your choice (e.g., `mkinitcpio`, `dracut`, `booster`, or another preferred tool).
1. **Create your own script and pacman hooks** to automate the addition and removal of kernels 
   using `limine-entry-tool` with different options.
1. Run `limine-install` to install Limine to `$ESP_PATH/EFI/limine/limine_x86.efi` (for x86_64 UEFI systems).

</details>

### Other Linux distributions

There are no pre-built packages for various package managers.
Package maintainers are welcome to create them.

<details>
<summary>Manual installation</summary>

1. Install `limine` and deploy it to your boot partition manually.
2. Clone the repository:
    ```shell
    git clone https://gitlab.com/Zesko/limine-entry-tool.git
    cd limine-entry-tool
    ```
3. Download [GraalVM 25](https://www.graalvm.org/latest/reference-manual/native-image/)
4. Build the project
    ```shell
    JAVA_HOME=<path-to-graalVM> gradle clean nativeCompile
    ```
5. Install the necessary files:
    ```shell
    cp build/native/nativeCompile/limine-entry-tool /usr/lib/limine/
    cp install/arch-linux/limine-entry-tool/usr/bin/limine* /usr/local/bin/
    cp -r install/arch-linux/limine-entry-tool/usr/lib/limine /usr/lib/
    ```
6. Create or edit a file `/etc/default/limine` and set: 
    ```
    ESP_PATH=/path/to/esp
    KERNEL_CMDLINE[default]="<Copy your kernel parameters from /proc/cmdline>"
    LIMINE_BINARY_PATH=/usr/share/limine/BOOTX64.EFI
    ```
   * Replace `/path/to/esp` with your actual boot partition (ESP) mount point (must be FAT32).
   * `LIMINE_BINARY_PATH=` is the path to Limine EFI binary that will be copied to the ESP by `limine-install` for UEFI.
7. Write your own automation script (or use system hooks) to invoke `limine-entry-tool`
for creating or removing boot entries when kernels are installed or removed.
8. Run `limine-install` to copy the Limine EFI binary to the ESP.

</details>

## Configuration

Optionally copy the default configuration to `/etc/default/limine` and adjust it as needed.

```properties
### OS Entry Targeting
### If TARGET_OS_NAME is not set, or if the default distro name is not found in $ESP_PATH/limine.conf,
### the tool will create a new OS entry using the default distro name (PRETTY_NAME or NAME from /etc/os-release) and machine-ID.
###
### Tips:
### If your custom OS entry already exists in $ESP_PATH/limine.conf, please add "comment: machine-id=<copy ID from /etc/machine-id>" under its name.
### The machine-ID helps the tool to automatically target the correct OS entry, so changing the OS name does not matter.
###
#TARGET_OS_NAME="Arch Linux"


### Boot Partition Path
### If not set, it is found automatically by checking /efi, /boot, /boot/efi, and /limine.
### Set this to skip the automatic search or if your boot partition uses a different mount path.
#ESP_PATH="/boot"


### Skip UEFI Check and Registration
### Skip UEFI check and bootloader registration on certain non-compliant UEFI boards (e.g., some MSI boards) (yes|no)
### If skipped, Limine will be used as the fallback bootloader on the standard UEFI path for all UEFI systems.
### Note:
### When set to yes, run 'limine-install' and manually set the BIOS boot order to make the standard UEFI path the default boot.
SKIP_UEFI=no


### Kernel Command Line Configuration
### Define one or more kernel command lines (parameters) for specific kernel entries.
### If unset, the tool will try to read them from '/etc/kernel/cmdline' or '/proc/cmdline'.
###
### Rules:
### * KERNEL_CMDLINE[default] applies to any kernel entries without specific configuration.
### * KERNEL_CMDLINE[fallback] applies to kernel entries with names containing *fallback*
### * KERNEL_CMDLINE[kernel name] applies to a specific kernel entry.
###
### Operators:
### * `+=` appends parameters to an existing cmdline for the same KERNEL_CMDLINE[<key>]
###    Commonly used in drop-in configs: /etc/limine-entry-tool.d/*.conf
###    Ignores /etc/kernel/cmdline and /proc/cmdline
### * `=` replaces an existing cmdline for the same KERNEL_CMDLINE[<key>]
###    Note: /etc/default/limine overrides any drop-in configs, so `+=` is recommended there.
###
### Tips:
### - If unsure which parameters to use, copy them from `/proc/cmdline` into KERNEL_CMDLINE[default],
###   but make sure your system is not a live ISO, temporary environment, or snapshot.
### - Multiple `initrd=` parameters are automatically converted into Limine module paths for non-UKI entries.
### - No quotes are needed at the start or end of command lines, since quotes inside are not escaped.
### - Do not add `#` as a comment at the end of command lines.
###
### Examples:
#KERNEL_CMDLINE[default]+=rw root=UUID=...
#KERNEL_CMDLINE[default]+=quiet splash acpi_osi="..."
#KERNEL_CMDLINE[default]+=initrd=/amd-ucode.img
#KERNEL_CMDLINE[fallback]=
#KERNEL_CMDLINE[linux-zen]=


### Formatting Boot Entry
### Define the number of spaces to indent each line of the boot entry in '$ESP_PATH/limine.conf'.
### If not set, the default is 2.
#SPACE_NUMBER=2


### Boot Integrity Check
### Enable BLAKE2 checksum verification for bootable files. (yes|no)
ENABLE_VERIFICATION=yes


### Automatic Config Backup
### Creates a backup of '$ESP_PATH/limine.conf' before saving any changes,
### but only if '$ESP_PATH/limine.conf.old' is older than the specified time (in hours).
### Default: 6 hours if unset.
#CONFIG_BACKUP_THRESHOLD=6


### Kernel Entries Order
### Wildcard "*" matches any letter in kernel-entry name 
### If ENABLE_SORT is set to "yes", only wildcard "*" entries are sorted alphabetically.
BOOT_ORDER="*, *fallback, Snapshots"
ENABLE_SORT=no


### Limine UEFI Binary Path
### Set the path to the Limine UEFI binary. Default: '/usr/share/limine/BOOTX64.EFI' (from the limine package on Arch Linux)
### It will be copied to '$ESP_PATH/EFI/limine/limine_x64.efi' when running 'limine-install'.
### Set SKIP_LIMINE_VERSION_CHECK=yes to always deploy the Limine binary regardless of version.
#LIMINE_BINARY_PATH="/usr/share/limine/BOOTX64.EFI"
#SKIP_LIMINE_VERSION_CHECK=no


### Default Boot Fallback
### Configure whether Limine should be installed as the default UEFI fallback loader. (yes|no|"")
### This helps preserve bootability on UEFI systems where BIOS, firmware, or Windows updates may remove custom Linux UEFI entries.
###
### Options:
### * "yes"               -> Always create, update, or overwrite the fallback on each limine-update.
### * "no"                -> Do nothing.
### * "" or commented out -> Create the fallback only if it is not present. If a fallback exists, leave it untouched.
###
### Note:
### With Secure Boot enabled, the default fallback is not signed automatically by limine-update for some reason.
### If you need to sign it, it is recommended to disable ENABLE_LIMINE_FALLBACK, run 'limine-install --fallback' once,
### and then sign the fallback manually.
###
#ENABLE_LIMINE_FALLBACK=""


### Find Bootloaders
### Automatically add systemd-boot, rEFInd, or the default EFI loader to Limine if they are found in the ESP. (yes|no)
FIND_BOOTLOADERS=yes


### Authentication Method
### Specify an authentication method: "sudo", "doas", "pkexec", "run0 --background=" or another method of your choice.
#AUTH_METHOD=sudo


### Quiet Mode
### Set to "yes" to hide all success messages and avoid log spam. (yes|no)
#QUIET_MODE=no


### Enroll Limine Config
### Automatically embeds a checksum of the Limine config into the Limine binary to protect it against unauthorized modifications.
###
### WARNING:
### Enabling this will PREVENT booting if you modify limine.conf without re-enrolling it afterward.
###
### If you are unsure but want to try it, run 'limine-install --fallback' first.
### This allows you to boot into the Limine fallback if a boot panic occurs due to a config checksum mismatch.
###
### IMPORTANT:
### * After editing limine.conf, always run 'limine-enroll-config'
### * Remove all other Limine configs from alternative locations to avoid boot failures.
### * If using limine-snapper-sync, make sure you have:
###   - /etc/boot/hooks/pre.d/ with a symlink 10-limine-reset-enroll -> /usr/bin/limine-reset-enroll
###   - /etc/boot/hooks/post.d/ with a symlink 90-limine-enroll-config -> /usr/bin/limine-enroll-config
### * If multiple systems share the same limine.conf, ensure each system handles enrollment automatically.
###
### To enable, copy this option to /etc/default/limine and set it to (yes|no)
ENABLE_ENROLL_LIMINE_CONFIG=no


### Custom UKI Name
### Set a shorter, custom name for UKI files instead of the default machine-id.
### This avoids issues when booting UKIs directly from some buggy UEFI firmware (e.g. Asus AMI BIOS)
### that may crash or freeze with long UKI filenames.
###
### Rules:
### * Custom name must be unique (like an ID) to avoid conflicts with other installations, otherwise UKIs will be overwritten.
### * Use only lowercase letters (a–z) and digits (0–9) for maximum compatibility with UEFI firmware and devices.
###
### Example: ${CUSTOM_UKI_NAME}_${kernel_version}.efi -> arch_linux-lts.efi (when CUSTOM_UKI_NAME="arch" is set)
### Default: The machine-id is used if the custom name is invalid or not set.
###
### Note:
### Changing the name does not remove existing UKI files with the previous name or machine-id.
### They remain unused on the ESP and can be removed manually to free up space.
### UKI location: $ESP_PATH/EFI/Linux/{machine-id or old name}_{kernel_version}.efi
#CUSTOM_UKI_NAME="arch"


##########  The below options apply to Arch Linux when 'limine-dracut-support' or 'limine-mkinitcpio-hook' is installed ###########

### UKI (Unified Kernel Image)
### Automatically create UKIs in '$ESP_PATH/EFI/Linux/' for UEFI. (yes|no)
###
### Advantages:
###  + UKIs can be detected and loaded by 'systemd-boot' or 'rEFInd'.
###  + UKIs can boot directly from UEFI firmware when a fixed UKI filename is manually registered as a UEFI boot entry.
### Disadvantage:
###  - UKIs require more ESP space than separate 'initramfs' and 'vmlinuz' files, especially with multiple snapshots.
###
### Additional notes:
###  * Duplicate 'initramfs' and 'vmlinuz' files are automatically removed after generating UKIs.
###  * With Snapper and Secure Boot enabled, UKIs use the kernel cmdline from 'limine.conf' instead of an embedded cmdline.
ENABLE_UKI=no


### Initramfs Fallback
### Automatically create a fallback initramfs or UKI. (yes|no|<kernel-name>)
### Set to 'yes' to create fallback images for all kernels.
### Set to a specific kernel name to create a fallback image only for that kernel.
### Fallback images consume additional storage space, especially when keeping multiple snapshots.
#MKINITCPIO_FALLBACK=linux-lts
#DRACUT_FALLBACK=linux-lts


### mkinitcpio UKI Build Options
### Additional options for mkinitcpio UKI builds
### See: https://man.archlinux.org/man/mkinitcpio.8.en#OPTIONS_FOR_UNIFIED_KERNEL_IMAGE
### Example: Add a splash screen
#MKINITCPIO_UKI_OPTIONS="--splash /usr/share/systemd/bootctl/splash-arch.bmp"
```

## Hooks

`limine-entry-tool` provides a hook mechanism that allows custom scripts to run during boot partition operations.

### Pre-hooks

Executable files in `/etc/boot/hooks/pre.d/` are executed **before** kernel management or `limine.conf` updates.<br>
Execution order is lexical: files with lower prefixes (e.g. `00-`) run before higher numbers.<br>
**Example execution order:**
1. `/etc/boot/hooks/pre.d/05-example-esp-set-rw` sets the boot partition to read-write mode.
2. `/etc/boot/hooks/pre.d/10-limine-reset-enroll` is a symlink to `limine-reset-enroll` and resets the Limine enrollment state.

### Post-hooks

Executable files in `/etc/boot/hooks/post.d/` are executed **after** kernel management and `limine.conf` updates.<br>
**Example execution order:**
1. `/etc/boot/hooks/post.d/90-limine-enroll-config` enrolls a Limine config checksum into the Limine binary and signs it.
2. `/etc/boot/hooks/post.d/91-example-esp-set-ro` sets the boot partition to **read-only** to prevent accidental or recursive modifications.

### Disabling hooks

A hook can be disabled by adding the `.disabled` suffix to its filename.

### Hook environment variables

* `HOOK_CALLER` identifies the tool or script name that triggered the hooks.
* `HOOK_CMDLINE` contains the full command line used by the caller.

### Hook failure handling

The **exit code** of a hook controls whether execution continues or stops:
* `0`     -> success, continue normally
* `1-99`  -> non-fatal error, continue with the next hook
* `>=100` -> fatal error, stop executing further hooks and terminate the main process

______________________

## Features

### Boot entry management

* Atomic mutex protection against concurrent access to the same boot partition
* Parsing of limine.conf
* Macro expansion support in limine.conf
* Verify configuration before processing
* Boot entries from limine.conf are converted into a tree structure for simplified management
* Identify a custom OS entry via machine-id based identification
* Identify a custom kernel entry name via kernel-id based identification
* Support for different boot parameters for individual kernels
* Kernel entry sorting based on `BOOT_ORDER`
* Custom UKI name for all kernel versions via `CUSTOM_UKI_NAME`
* Atomic file writes on FAT32 to reduce the risk of corruption during power outages, crashes, or hard resets
* Automatic backup of limine.conf before modifications
* Protection against unintended Limine downgrades when restoring older system snapshots
* Fallback bootloader deployment
* Custom Limine EFI binary support through `SKIP_LIMINE_VERSION_CHECK` and `LIMINE_BINARY_PATH`

### Integrity

* BLAKE2b checksum generation for each boot image when `ENABLE_VERIFICATION` is enabled
* Automatic Limine configuration checksum updates and enrollment into the Limine binary after kernel management
* Hardware fault detection through comparison of two independently generated file hashes

### System integration & UX

* Some safeguards to reduce breakages from user errors
* Ensure /etc/machine-id exists, generate if missing
* Automatic detection of default OS name from /etc/os-release
* Authentication helper to avoid typing `sudo` or other auth methods every time
* Pre- and post-hooks for running custom scripts before or after kernel management
* Terminal input support with arrow-key navigation (Up, Down, Left, Right)
* UKI or initramfs (dracut or mkinitcpio) integration for Arch Linux
* Avoid rewriting identical initramfs or UKI files to reduce unnecessary SSD writes
* Support generating UKI or initramfs fallback images for a user-selected kernel or all kernels

______________________

### Donate

If you would like to support the project, feel free to donate:

[<img src="https://gitlab.com/Zesko/resources/-/raw/main/kofiButton.png" width=110px>](https://ko-fi.com/zeskotron)
&nbsp;[<img src="https://gitlab.com/Zesko/resources/-/raw/main/PayPalButton.png" width=160px/>](https://www.paypal.com/donate/?hosted_button_id=XKP36D62AY5HY)

##### Planned features

- **Support for smaller ESP sizes** by storing bootable files on a separate FAT32 partition.
- **Multiple boot partitions:** Ensures kernel and Limine redundancy on UEFI systems if one boot partition is wiped.
- **BLS support:** Automatically parses existing BLS files and generates corresponding Limine boot entries.
- **Multiple boot profiles per kernel:** Allow multiple cmdlines for the same kernel via `KERNEL_CMDLINE[k][p]` config.
- **Configurable Limine protocol options** for individual kernel entries.
- **Full Kotlin rewrite:** Optimized code using standard libraries to improve performance compared to version 1.
