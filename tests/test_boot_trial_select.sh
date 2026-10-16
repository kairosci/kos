#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
source "$PROJECT_DIR/scripts/lib/boot-trial-select.sh"
WORK_DIR=$(mktemp -d)
trap 'rm -rf -- "$WORK_DIR"' EXIT
POLICY="$PROJECT_DIR/data/component/boot/policy.json"
log() { printf '%s\n' "$*" >> "$WORK_DIR/log"; }
efibootmgr() {
    if [[ "$1" == --bootnext ]]; then
        printf '%s\n' "$2" > "$WORK_DIR/selected"
        return 0
    fi
    cat "$WORK_DIR/firmware"
    if [[ -f "$WORK_DIR/selected" ]]; then
        printf 'BootNext: %s\n' "$(cat "$WORK_DIR/selected")"
    fi
}
cat > "$WORK_DIR/firmware" <<'FIRMWARE'
BootOrder: 0001,0009
Boot0000* OS GRUB trial	HD(1,GPT,fixture)/\EFI\OS-GRUB\grubx64.efi
Boot0001* Limine	HD(1,GPT,fixture)/\EFI\limine\limine_x64.efi
FIRMWARE
cp "$WORK_DIR/firmware" "$WORK_DIR/original"
assert_true "trial selects the exact candidate for one boot" 'boot_trial_select "$POLICY" && [[ $(cat "$WORK_DIR/selected") == 0000 ]]'
assert_true "trial preserves permanent firmware order" 'cmp -s "$WORK_DIR/firmware" "$WORK_DIR/original"'
rm "$WORK_DIR/selected"
sed -i 's/OS GRUB trial/OS GRUB trial other/' "$WORK_DIR/firmware"
assert_false "similar labels cannot select a different bootloader" 'boot_trial_select "$POLICY"'
assert_true "invalid labels never write BootNext" '[[ ! -e "$WORK_DIR/selected" ]]'
cp "$WORK_DIR/original" "$WORK_DIR/firmware"
sed -i 's/OS-GRUB/OTHER/' "$WORK_DIR/firmware"
assert_false "matching labels with a different EFI path are rejected" 'boot_trial_select "$POLICY"'
cp "$WORK_DIR/original" "$WORK_DIR/firmware"
printf 'Boot0002* OS GRUB trial\tHD(1,GPT,fixture)/\\EFI\\OS-GRUB\\grubx64.efi\n' >> "$WORK_DIR/firmware"
assert_false "ambiguous firmware candidates prevent selection" 'boot_trial_select "$POLICY"'
assert_true "ambiguous candidates leave BootNext unset" '[[ ! -e "$WORK_DIR/selected" ]]'
test_summary
