#!/usr/bin/env bash

set -euo pipefail

log "firewall.configure"
if ! pacman -Q ufw &>/dev/null; then
    pacman -S --noconfirm --needed ufw
fi
ufw default deny incoming
ufw default allow outgoing
ufw allow 53317/udp
ufw allow 53317/tcp
for _ufw_rules in /etc/ufw/{user,before,after}{,6}.rules; do
    [[ -f "$_ufw_rules" ]] || continue
    chmod 640 "$_ufw_rules"
done
ufw --force enable || warn "firewall.already_active"
systemctl enable ufw.service || warn "firewall.service_enabled"
