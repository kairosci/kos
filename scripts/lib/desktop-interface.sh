#!/usr/bin/env bash
set -euo pipefail

for _health_module in gtk hyprmod; do
    user_as "$PRIMARY_USER" bash "$PROJECT_DIR/modules/conf/$_health_module/install.sh" || err "defaults.app_failed" "$_health_module"
done
user_as "$PRIMARY_USER" bash -c '
    set -euo pipefail
    source "$1/scripts/lib/userconf.sh"
    config="${XDG_CONFIG_HOME:-$HOME/.config}/os/hooks"
    for hook in "$1"/hooks/theme-set.d/*; do
        install_user_file "$hook" "$config/theme-set.d/${hook##*/}" 755
    done
    install_user_file "$1/scripts/lib/i18n.sh" "$config/i18n/i18n.sh"
    install_user_file "$1/scripts/lib/i18n-boot.sh" "$config/i18n/i18n-boot.sh"
    for catalog in "$1"/scripts/lib/messages/*.msg; do
        install_user_file "$catalog" "$config/i18n/messages/${catalog##*/}"
    done
    install_user_file "$1/hooks/post-update.d/99-os-persist" "$config/post-update.d/99-os-persist" 755
    bash "$config/theme-set.d/gtk-theme"
' bash "$PROJECT_DIR" || err "defaults.app_failed" "desktop theme"
user_as "$PRIMARY_USER" hyprctl reload config-only || err "session.validation_failed" Hyprland
_health_errors=$(user_as "$PRIMARY_USER" hyprctl configerrors) || err "session.validation_failed" Hyprland
[[ -z "${_health_errors//[[:space:]]/}" ]] || err "session.validation_failed" "$_health_errors"
