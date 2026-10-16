#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
test_section "Verified GRUB candidate and snapshot recovery"
assert_file_contains "all bootloader setup uses the verified candidate implementation" "$PROJECT_DIR/scripts/lib/modules/27-bootloader.sh" 'scripts/lib/grub-trial.sh'
assert_file_contains "candidate installation cannot change firmware order" "$PROJECT_DIR/scripts/lib/grub-trial.sh" '\-\-no-nvram'
assert_file_contains "candidate registration does not select a boot target" "$PROJECT_DIR/scripts/lib/grub-trial.sh" '\-\-create-only'
assert_file_contains "candidate checks firmware order after registration" "$PROJECT_DIR/scripts/lib/grub-trial.sh" '_trial_before.*==.*_trial_after'
assert_file_contains "candidate requires preserved recovery image" "$PROJECT_DIR/scripts/lib/grub-trial.sh" '_trial_esp\$_trial_recovery'
assert_file_contains "boot menu uses verified native EFI command lines" "$PROJECT_DIR/modules/platform/arch/scripts/boot-menu.rb" 'chainloader.*cmdline'
assert_file_contains "menu syntax is validated before publication" "$PROJECT_DIR/scripts/lib/grub-menu.sh" 'grub-script-check'
assert_file_contains "menu publication replaces the complete file atomically" "$PROJECT_DIR/scripts/lib/grub-menu.sh" 'mv -f'
assert_file_contains "boot menu uses cyan selection policy" "$PROJECT_DIR/modules/platform/arch/data/boot.json" 'black/cyan'
assert_file_contains "bootloader has a dedicated setup scope" "$PROJECT_DIR/scripts/setup.sh" 'SETUP_SCOPE.*bootloader'
assert_file_contains "full setup includes GRUB provisioning" "$PROJECT_DIR/scripts/setup.sh" '27-bootloader.sh'
assert_file_contains "recovery rolls back the selected Snapper snapshot" "$PROJECT_DIR/scripts/lib/root-recovery.sh" 'snapper -c root rollback'
assert_file_contains "snapshot cleanup invokes the canonical menu generator" "$PROJECT_DIR/scripts/lib/snapshot-baseline.sh" 'os-grub-menu'
assert_file_contains "security reconciliation invokes the same generator" "$PROJECT_DIR/scripts/lib/modules/85-security-stack.sh" 'os-grub-menu'
assert_file_not_contains "candidate never rewrites initramfs policy" "$PROJECT_DIR/scripts/lib/grub-trial.sh" 'mkinitcpio -P'
assert_file_not_contains "candidate never requests a reboot" "$PROJECT_DIR/scripts/lib/grub-trial.sh" 'systemctl reboot'
test_summary
