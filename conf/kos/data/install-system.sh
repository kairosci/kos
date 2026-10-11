#!/usr/bin/env bash
set -euo pipefail
source /usr/share/kos/lib/i18n.sh
i18n_init
[[ $EUID == 0 && $# == 2 ]] || err release.invalid
target=$(realpath -e "$1")
user="$2"
[[ "$target" != / && "$user" =~ ^[a-z_][a-z0-9_-]*$ && "$user" != root ]] || err release.invalid
mountpoint -q "$target" || err release.invalid
[[ -r "$target/usr/lib/os-release" && -d "$target/home/$user" ]] || err release.invalid
grep -qE '^ID=(arch|"arch")$' "$target/usr/lib/os-release" || err release.invalid
arch-chroot "$target" id "$user" >/dev/null || err release.invalid
packages=(/opt/kos/kos-*.pkg.tar.zst)
[[ ${#packages[@]} == 1 ]] || err release.invalid
for package in "${packages[@]}"; do
    [[ -f "$package" ]] || err release.invalid
done
install -d -m 700 "$target/var/cache/kos"
cp "${packages[@]}" "$target/var/cache/kos/"
arch-chroot "$target" pacman -Syu --needed --noconfirm
arch-chroot "$target" bash -c 'set -euo pipefail; pacman -U --noconfirm /var/cache/kos/*.pkg.tar.zst'
arch-chroot "$target" bash -c 'set -euo pipefail; backup=$(mktemp -d /var/lib/kos-install-home.XXXXXX); chmod 700 "$backup"; cp -a "/home/$1/." "$backup/"; cp -a /etc/skel/. "/home/$1/"; chown -R "$1:$1" "/home/$1"; usermod -aG wheel "$1"' bash "$user"
install -d -m 755 "$target/etc/kos"
printf 'KOS_SETUP_USER=%s\n' "$user" > "$target/etc/kos/install.conf"
uid=$(arch-chroot "$target" id -u "$user")
install -d -m 755 "$target/etc/systemd/system/kos-first-boot.service.d" "$target/var/lib/systemd/linger"
printf '[Unit]\nWants=user@%s.service\nAfter=user@%s.service\n' "$uid" "$uid" > "$target/etc/systemd/system/kos-first-boot.service.d/user.conf"
install -m 644 /dev/null "$target/var/lib/systemd/linger/$user"
arch-chroot "$target" systemctl enable NetworkManager sddm kos-first-boot
