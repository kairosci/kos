#!/usr/bin/env bash
set -euo pipefail

_trial_policy="$PROJECT_DIR/data/component/boot/policy.json"
_trial_id=$(jq -er '.candidateId | select(test("^[A-Za-z][A-Za-z-]*$"))' "$_trial_policy") || err "bootloader.install_failed"
"$PROJECT_DIR/script/os-lua" boot-assessment
_trial_esp=$(findmnt -nro TARGET /boot) || err "bootloader.esp_missing"
[[ "$_trial_esp" == /boot && "$(findmnt -nro FSTYPE /boot)" == vfat ]] || err "bootloader.esp_missing"
_trial_before=$(efibootmgr | sed -n 's/^BootOrder: //p') || err "bootloader.install_failed"
mapfile -t _trial_packages < "$PROJECT_DIR/data/core/dependencies.list"
for _trial_package in "${_trial_packages[@]}"; do
    [[ "$_trial_package" =~ ^[a-z][a-z0-9-]*$ ]] || err "bootloader.install_failed"
done
OMARCHY_ALLOW_DIRECT_PACMAN=1 pacman -Syu --noconfirm --needed "${_trial_packages[@]}" || err "bootloader.install_failed"
install -d -m 755 /usr/share/os/lib/messages
install -m 644 "$PROJECT_DIR"/data/catalog/*.msg /usr/share/os/lib/messages/
while IFS= read -r -d '' _trial_file; do
    install -Dm644 "$_trial_file" "/usr/share/os/${_trial_file#"$PROJECT_DIR/"}"
done < <(find -L "$PROJECT_DIR/src" "$PROJECT_DIR/data" -type f -print0)
install -Dm755 "$PROJECT_DIR/script/os-lua" /usr/share/os/script/os-lua
install -Dm644 "$_trial_policy" /usr/share/os/boot-policy.json
install -d -m 755 /usr/local/libexec /usr/local/bin
ln -sfn /usr/share/os/script/os-lua /usr/local/libexec/os-grub-menu
ln -sfn /usr/share/os/script/os-lua /usr/local/bin/os-grub-menu
/usr/local/libexec/os-grub-menu || err "bootloader.config_failed"
while IFS= read -r _trial_retired; do
    [[ "$_trial_retired" == /usr/share/os/* && "$_trial_retired" != *..* ]] || err "bootloader.install_failed"
    rm -f -- "$_trial_retired"
done < "$PROJECT_DIR/data/core/retired.list"
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
ln -sfn /usr/share/os/script/os-lua /etc/boot/hooks/post.d/99-os-grub-menu
log "bootloader.configured"
