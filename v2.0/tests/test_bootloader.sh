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
assert_file_contains "boot menu uses verified native EFI command lines" "$PROJECT_DIR/src/component/boot/menu.lua" 'entry.cmdline'
assert_file_contains "menu syntax is validated before publication" "$PROJECT_DIR/src/component/runtime/application.lua" 'validateGrub'
assert_file_contains "menu publication replaces the complete file atomically" "$PROJECT_DIR/src/core/publisher.lua" 'os.rename'
assert_file_contains "shared Lua starter resolves its installed symlink" "$PROJECT_DIR/script/os-lua" 'readlink -f'
assert_file_contains "GRUB executable alias dispatches to Lua" "$PROJECT_DIR/script/os-lua" 'publish-grub'
assert_file_contains "GRUB aliases point to the shared Lua starter" "$PROJECT_DIR/scripts/lib/grub-trial.sh" 'ln -sfn /usr/share/os/script/os-lua /usr/local/libexec/os-grub-menu'
assert_file_contains "boot hook points to the shared Lua starter" "$PROJECT_DIR/scripts/lib/grub-trial.sh" 'ln -sfn /usr/share/os/script/os-lua /etc/boot/hooks/post.d/99-os-grub-menu'
assert_true "legacy GRUB menu shell starter is retired" "[[ ! -e '$PROJECT_DIR/scripts/lib/grub-menu.sh' ]]"
assert_file_contains "boot menu uses cyan selection policy" "$PROJECT_DIR/data/component/boot/policy.json" 'black/cyan'
assert_file_contains "bootloader has a dedicated setup scope" "$PROJECT_DIR/scripts/setup.sh" 'SETUP_SCOPE.*bootloader'
assert_file_contains "full setup includes GRUB provisioning" "$PROJECT_DIR/scripts/setup.sh" '27-bootloader.sh'
assert_file_contains "recovery rolls back the selected Snapper snapshot" "$PROJECT_DIR/scripts/lib/root-recovery.sh" 'snapper -c root rollback'
assert_file_contains "snapshot cleanup invokes the canonical menu generator" "$PROJECT_DIR/scripts/lib/snapshot-baseline.sh" 'os-grub-menu'
assert_file_contains "security reconciliation invokes the same Lua generator" "$PROJECT_DIR/src/component/security/stack.lua" 'grubMenuUpdate'
assert_file_not_contains "candidate never rewrites initramfs policy" "$PROJECT_DIR/scripts/lib/grub-trial.sh" 'mkinitcpio -P'
assert_file_not_contains "candidate never requests a reboot" "$PROJECT_DIR/scripts/lib/grub-trial.sh" 'systemctl reboot'
test_summary
