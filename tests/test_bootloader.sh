#!/usr/bin/env bash

Os::tests::test_bootloader_sh::run() {

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"

test_section "GRUB text boot and snapshot recovery"
assert_file_exists "bootloader module exists" "$PROJECT_DIR/scripts/lib/modules/27-bootloader.sh"
assert_file_exists "GRUB defaults exist" "$PROJECT_DIR/conf/bootloader/grub"
assert_file_exists "cyan text menu generator exists" "$PROJECT_DIR/conf/bootloader/08_os_console_theme"
assert_file_exists "GRUB defaults reconciler exists" "$PROJECT_DIR/scripts/lib/grub-configure.sh"
assert_file_contains "bootloader provisions GRUB with Btrfs snapshot support" "$PROJECT_DIR/scripts/lib/modules/27-bootloader.sh" 'grub grub-btrfs inotify-tools'
assert_file_contains "bootloader configures a text console" "$PROJECT_DIR/conf/bootloader/grub" 'GRUB_TERMINAL=console'
assert_file_contains "GRUB core preloads TPM measurement support" "$PROJECT_DIR/conf/bootloader/grub" 'GRUB_PRELOAD_MODULES="tpm"'
assert_file_contains "boot menu uses cyan selection" "$PROJECT_DIR/conf/bootloader/08_os_console_theme" 'menu_color_highlight'
assert_file_contains "snapshot overlay kernel parameter is configured" "$PROJECT_DIR/scripts/lib/modules/27-bootloader.sh" 'rd.live.overlay.overlayfs=1'
assert_file_contains "snapshot watcher is enabled" "$PROJECT_DIR/scripts/lib/modules/27-bootloader.sh" 'grub-btrfsd.service'
assert_file_contains "bootloader has a dedicated setup scope" "$PROJECT_DIR/scripts/setup.sh" 'SETUP_SCOPE.*bootloader'
assert_file_contains "full setup includes GRUB provisioning" "$PROJECT_DIR/scripts/setup.sh" '27-bootloader.sh'
assert_file_contains "recovery rolls back the selected Snapper snapshot" "$PROJECT_DIR/scripts/lib/root-recovery.sh" 'snapper -c root rollback'
assert_file_contains "snapshot cleanup regenerates GRUB entries" "$PROJECT_DIR/scripts/lib/snapshot-baseline.sh" 'grub-mkconfig -o /boot/grub/grub.cfg'
assert_file_contains "GRUB defaults preserve unrelated settings" "$PROJECT_DIR/scripts/lib/grub-configure.sh" 'GRUB_'
assert_file_not_contains "Limine theme files are retired" "$PROJECT_DIR/scripts/setup.sh" '27-limine-theme.sh'

test_summary

}

Os::tests::test_bootloader_sh::run "$@"
