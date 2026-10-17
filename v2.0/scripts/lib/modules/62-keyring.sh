#!/usr/bin/env bash
set -euo pipefail

KEYRING_BACKEND=gnome-keyring
if [[ -n "${OS_KEYRING_BACKEND:-}" && "$OS_KEYRING_BACKEND" != "$KEYRING_BACKEND" ]]; then
    err "keyring.backend_invalid" "$OS_KEYRING_BACKEND"
fi
log "keyring.install"
pacman -S --noconfirm --needed gnome-keyring seahorse libsecret pass
systemctl --global unmask gnome-keyring-daemon.service gnome-keyring-daemon.socket

for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    user=$(basename "$user_home")
    uid=$(id -u "$user")
    dbus_service="$user_home/.local/share/dbus-1/services/org.freedesktop.secrets.service"
    if [[ -f "$dbus_service" ]] && grep -q '^Exec=/usr/bin/keepassxc' "$dbus_service"; then
        rm -f "$dbus_service"
    fi
    for unit in gnome-keyring-daemon.service gnome-keyring-daemon.socket; do
        unit_mask="$user_home/.config/systemd/user/$unit"
        if [[ -L "$unit_mask" && $(readlink "$unit_mask") == /dev/null ]]; then
            rm -f "$unit_mask"
        fi
    done
    for launcher in gnome-keyring-pkcs11.desktop gnome-keyring-secrets.desktop gnome-keyring-ssh.desktop; do
        autostart="$user_home/.config/autostart/$launcher"
        if [[ -f "$autostart" ]] && grep -qx 'Hidden=true' "$autostart"; then
            rm -f "$autostart"
        fi
    done
    if pgrep -u "$uid" -x keepassxc >/dev/null; then
        pkill -TERM -u "$uid" -x keepassxc
        for attempt in {1..50}; do
            pgrep -u "$uid" -x keepassxc >/dev/null || break
            sleep 0.1
        done
        if pgrep -u "$uid" -x keepassxc >/dev/null; then
            err "keyring.stop_failed" "$user"
        fi
    fi
    if [[ -S "/run/user/$uid/bus" ]]; then
        user_as "$user" systemctl --user daemon-reload
        user_as "$user" systemctl --user unmask gnome-keyring-daemon.service gnome-keyring-daemon.socket
        user_as "$user" systemctl --user enable --now gnome-keyring-daemon.socket gnome-keyring-daemon.service
    fi
    keyring_dir="$user_home/.config/python_keyring"
    install -d -m 700 -o "$user" -g "$user" "$keyring_dir"
    printf '[backend]\ndefault-keyring=keyring.backends.SecretService.Keyring\n' > "$keyring_dir/keyringrc.cfg"
    chown "$user:$user" "$keyring_dir/keyringrc.cfg"
    chmod 600 "$keyring_dir/keyringrc.cfg"
done

log "keyring.pam_integrate"
for pam_file in /etc/pam.d/login /etc/pam.d/sddm /etc/pam.d/gdm-password /etc/pam.d/greetd /etc/pam.d/lightdm; do
    [[ -f "$pam_file" ]] || continue
    grep -Eq '^auth[[:space:]]+optional[[:space:]]+pam_gnome_keyring.so' "$pam_file" || printf '\nauth optional pam_gnome_keyring.so\n' >> "$pam_file"
    grep -Eq '^session[[:space:]]+optional[[:space:]]+pam_gnome_keyring.so.*auto_start' "$pam_file" || printf 'session optional pam_gnome_keyring.so auto_start\n' >> "$pam_file"
done
if [[ -f /etc/pam.d/passwd ]]; then
    grep -Eq '^password[[:space:]]+optional[[:space:]]+pam_gnome_keyring.so' /etc/pam.d/passwd || printf '\npassword optional pam_gnome_keyring.so use_authtok\n' >> /etc/pam.d/passwd
fi
install -d -m 755 /etc/os
printf '%s\n' "$KEYRING_BACKEND" > /etc/os/keyring-backend
chmod 644 /etc/os/keyring-backend
