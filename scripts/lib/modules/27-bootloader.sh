#!/usr/bin/env bash

set -euo pipefail

log "bootloader.install"
pacman -S --noconfirm --needed grub grub-btrfs inotify-tools || err "bootloader.install_failed"
install -Dm755 "$PROJECT_ROOT/scripts/lib/grub-configure.sh" /usr/local/libexec/os-grub-configure
install -Dm644 "$PROJECT_ROOT/conf/bootloader/grub" /usr/share/os/grub-defaults
install -Dm755 "$PROJECT_ROOT/conf/bootloader/08_os_console_theme" /etc/grub.d/08_os_console_theme

ESP_PATH=$(findmnt --noheadings --raw --output TARGET --types vfat | head -n 1) || err "bootloader.esp_missing"
[[ -n "$ESP_PATH" && -d "$ESP_PATH" ]] || err "bootloader.esp_missing"
[[ $(findmnt --noheadings --raw --output TARGET --types vfat | wc -l) -eq 1 ]] || err "bootloader.esp_ambiguous"
install -d -m 755 "$ESP_PATH/EFI/os"
grub-install --target=x86_64-efi --efi-directory="$ESP_PATH" --bootloader-id=os --modules=tpm --recheck || err "bootloader.install_failed"
/usr/local/libexec/os-grub-configure
if [[ -f /etc/default/grub-btrfs/config ]]; then
    if ! grep -Fxq 'GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="rd.live.overlay.overlayfs=1"' /etc/default/grub-btrfs/config; then
        printf '%s\n' 'GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="rd.live.overlay.overlayfs=1"' >> /etc/default/grub-btrfs/config
    fi
fi
if [[ -f /etc/mkinitcpio.conf ]] && ! grep -Eq '^[[:space:]]*HOOKS=.*grub-btrfs-overlayfs' /etc/mkinitcpio.conf; then
    sed -i -E '/^[[:space:]]*HOOKS=/ s/\)[[:space:]]*$/ grub-btrfs-overlayfs)/' /etc/mkinitcpio.conf
    grep -Eq '^[[:space:]]*HOOKS=.*grub-btrfs-overlayfs' /etc/mkinitcpio.conf || err "bootloader.initramfs_failed"
    mkinitcpio -P || err "bootloader.initramfs_failed"
fi
systemctl enable grub-btrfsd.service || err "bootloader.daemon_failed"
grub-mkconfig -o /boot/grub/grub.cfg || err "bootloader.config_failed"

install -d -m 755 /etc/boot/hooks/post.d
cat > /etc/boot/hooks/post.d/85-os-grub-config << 'HOOK'
#!/usr/bin/env bash
set -euo pipefail
/usr/local/libexec/os-grub-configure
grub-mkconfig -o /boot/grub/grub.cfg
HOOK
chmod 755 /etc/boot/hooks/post.d/85-os-grub-config
