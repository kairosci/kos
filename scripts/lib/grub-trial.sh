#!/usr/bin/env bash
set -euo pipefail

_trial_policy="$PROJECT_DIR/modules/platform/arch/data/boot.json"
_trial_id=$(jq -er '.candidateId | select(test("^[A-Za-z][A-Za-z-]*$"))' "$_trial_policy") || err "bootloader.install_failed"
source "$PROJECT_DIR/scripts/lib/boot-assessment.sh"
boot_assessment /var/lib/os/boot-assessment
_trial_esp=$(findmnt -nro TARGET /boot) || err "bootloader.esp_missing"
[[ "$_trial_esp" == /boot && "$(findmnt -nro FSTYPE /boot)" == vfat ]] || err "bootloader.esp_missing"
_trial_before=$(efibootmgr | sed -n 's/^BootOrder: //p') || err "bootloader.install_failed"
OMARCHY_ALLOW_DIRECT_PACMAN=1 pacman -Syu --noconfirm --needed grub ruby ruby-openssl || err "bootloader.install_failed"
install -Dm644 "$PROJECT_DIR/modules/platform/arch/scripts/boot-menu.rb" /usr/share/os/modules/platform/arch/scripts/boot-menu.rb
install -Dm644 "$PROJECT_DIR/modules/core/scripts/catalog.rb" /usr/share/os/modules/core/scripts/catalog.rb
install -Dm644 "$PROJECT_DIR/modules/core/data/locale.json" /usr/share/os/modules/core/data/locale.json
install -d -m 755 /usr/share/os/lib/messages
install -m 644 "$PROJECT_DIR"/scripts/lib/messages/*.msg /usr/share/os/lib/messages/
install -Dm644 "$_trial_policy" /usr/share/os/boot-policy.json
install -Dm755 "$PROJECT_DIR/scripts/lib/grub-menu.sh" /usr/local/libexec/os-grub-menu
install -Dm755 "$PROJECT_DIR/conf/bootloader/grub-menu-command" /usr/local/bin/os-grub-menu
/usr/local/libexec/os-grub-menu || err "bootloader.config_failed"
grub-install --target=x86_64-efi --efi-directory="$_trial_esp" --bootloader-id="$_trial_id" --no-nvram --recheck || err "bootloader.install_failed"
_trial_recovery=$(jq -er '.fallbackImage | select(startswith("/EFI/") and (contains("..") | not))' "$_trial_policy") || err "bootloader.install_failed"
[[ -s "$_trial_esp/EFI/$_trial_id/grubx64.efi" && -s "$_trial_esp$_trial_recovery" ]] || err "bootloader.install_failed"
_trial_label=$(jq -er '.candidateLabel' "$_trial_policy") || err "bootloader.install_failed"
_trial_firmware=$(efibootmgr -v) || err "bootloader.install_failed"
if ! grep -Fq "$_trial_label" <<< "$_trial_firmware"; then
    _trial_device=$(findmnt -nro SOURCE "$_trial_esp") || err "bootloader.esp_missing"
    _trial_parent=$(lsblk -ndo PKNAME "$_trial_device") || err "bootloader.esp_missing"
    _trial_partition=$(cat "/sys/class/block/${_trial_device##*/}/partition") || err "bootloader.esp_missing"
    [[ "$_trial_parent" =~ ^[a-zA-Z0-9_-]+$ && "$_trial_partition" =~ ^[0-9]+$ ]] || err "bootloader.esp_missing"
    efibootmgr --create-only --disk "/dev/$_trial_parent" --part "$_trial_partition" --label "$_trial_label" --loader "\\EFI\\$_trial_id\\grubx64.efi" || err "bootloader.install_failed"
fi
_trial_after=$(efibootmgr | sed -n 's/^BootOrder: //p') || err "bootloader.install_failed"
[[ "$_trial_before" == "$_trial_after" ]] || err "bootloader.install_failed"
install -d -m 755 /etc/boot/hooks/post.d
install -m 755 "$PROJECT_DIR/conf/bootloader/grub-menu-hook" /etc/boot/hooks/post.d/99-os-grub-menu
log "bootloader.configured"
