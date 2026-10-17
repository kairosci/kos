#!/usr/bin/env bash
set -euo pipefail

source "$MODULES_DIR/97-session.sh" --files-only
install -m 755 "$PROJECT_DIR/scripts/lib/keyboard-backlight.sh" /usr/local/libexec/os-keyboard-backlight
install -m 755 "$PROJECT_DIR/modules/theme-previews/scripts/update-previews.sh" /usr/local/libexec/os-update-previews
install -m 755 "$PROJECT_DIR/scripts/lib/desktop-cleanup.sh" /usr/local/libexec/os-desktop-cleanup

_health_packages=()
for _health_list in "$PROJECT_DIR/modules/conf/easyeffects/data/packages.list" "$PROJECT_DIR/modules/conf/hyprmod/data/packages.list" "$PROJECT_DIR/modules/conf/session/data/desktop-packages.list"; do
    [[ -r "$_health_list" ]] || err "defaults.app_failed" "$_health_list"
    while IFS= read -r _health_package; do
        [[ "$_health_package" =~ ^[a-z0-9][a-z0-9.-]*$ ]] || err "env.aur_invalid" "$_health_package"
        _health_packages+=("$_health_package")
    done < "$_health_list"
done
OMARCHY_ALLOW_DIRECT_PACMAN=1 pacman -Syu --noconfirm --needed "${_health_packages[@]}" || err "defaults.app_failed" "desktop health"
source "$MODULES_DIR/81-resolver-failover.sh"
source "$SCRIPT_DIR/lib/keyboard-backlight-policy.sh"
source "$MODULES_DIR/36-os-cli.sh"
source "$SCRIPT_DIR/lib/desktop-interface.sh"

user_as "$PRIMARY_USER" bash "$PROJECT_DIR/modules/conf/easyeffects/install.sh" || err "defaults.app_failed" EasyEffects
