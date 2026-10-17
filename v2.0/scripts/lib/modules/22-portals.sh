#!/usr/bin/env bash

set -euo pipefail

log "portals.install"
pacman -S --noconfirm --needed xdg-desktop-portal-hyprland xdg-desktop-portal-gtk || err "portals.install_failed"
source "$PROJECT_DIR/scripts/lib/desktop-workflow.sh"

log "portals.configure"
for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    desktop_workflow_portals "$_user" "$user_home" || err "portals.configure_failed" "$_user"
done
