#!/usr/bin/env bash

set -euo pipefail

aur_verified_install() {
    local pkg="${1:-}"
    [[ -n "$pkg" ]] || err "env.aur_empty"
    [[ "$pkg" =~ ^[a-zA-Z0-9._-]+$ ]] || err "env.aur_invalid" "$pkg"
    "$PROJECT_DIR/script/os-lua" install-aur "$pkg" "$PRIMARY_USER" || err "defaults.app_failed" "$pkg"
}

user_as() {
    local user="$1"
    shift
    [[ -n "$user" ]] || { warn "env.user_as_no_user"; return 1; }
    local home="" runtime="" bus="" uid=""
    home=$(getent passwd "$user" 2>/dev/null | cut -d: -f6)
    [[ -n "$home" ]] || home="/home/$user"
    uid=$(id -u "$user" 2>/dev/null || printf '')
    if [[ -n "$uid" && -d "/run/user/$uid" ]]; then
        runtime="/run/user/$uid"
        bus="unix:path=/run/user/$uid/bus"
    fi
    local -a _env=(
        "HOME=$home"
        "USER=$user"
        "LOGNAME=$user"
        "XDG_CONFIG_HOME=$home/.config"
        "XDG_DATA_HOME=$home/.local/share"
        "XDG_STATE_HOME=$home/.local/state"
        "XDG_CACHE_HOME=$home/.cache"
        "PATH=$home/.local/bin:/usr/share/omarchy/bin:/usr/local/bin:/usr/bin:/usr/sbin:/bin"
        "XDG_RUNTIME_DIR=$runtime"
        "DBUS_SESSION_BUS_ADDRESS=$bus"
    )
    if [[ -n "${OS_LANG:-}" ]]; then _env+=("OS_LANG=$OS_LANG"); fi
    if [[ -n "${OS_FORCE_TZ:-}" ]]; then _env+=("OS_FORCE_TZ=$OS_FORCE_TZ"); fi
    local session_env entry
    if [[ -n "$bus" ]] && session_env=$(sudo -u "$user" env "XDG_RUNTIME_DIR=$runtime" "DBUS_SESSION_BUS_ADDRESS=$bus" systemctl --user show-environment </dev/null); then
        while IFS= read -r entry; do
            case "$entry" in
                WAYLAND_DISPLAY=*|DISPLAY=*|HYPRLAND_INSTANCE_SIGNATURE=*|XDG_CURRENT_DESKTOP=*|XDG_SESSION_TYPE=*) _env+=("$entry") ;;
            esac
        done <<< "$session_env"
    fi
    sudo -u "$user" env -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION \
        -u SUDO_USER -u SUDO_UID -u SUDO_GID -u PKEXEC_UID "${_env[@]}" \
        bash -c 'cd "$HOME" && exec "$@"' bash "$@"
}

omarchy_as() {
    local user="$1"
    shift
    [[ -n "$user" ]] || { warn "env.omarchy_as_no_user"; return 1; }
    if [[ -z "${OMARCHY_PATH:-}" ]]; then
        if [[ -f /usr/share/omarchy/default/bash/env-bootstrap ]]; then
            source /usr/share/omarchy/default/bash/env-bootstrap 2>/dev/null || warn "env.omarchy_bootstrap_skipped"
        fi
        OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
    fi
    user_as "$user" env "OMARCHY_PATH=$OMARCHY_PATH" omarchy "$@"
}

[[ "${1:-}" != --functions-only ]] || return 0

log "env.sync"
OMARCHY_ALLOW_DIRECT_PACMAN=1 pacman -Syu --noconfirm || err "env.sync_skipped"

log "env.fixing_broken"
for pkg_dir in /var/lib/pacman/local/*/; do
    [[ -d "$pkg_dir" ]] || continue
    [[ -f "$pkg_dir/desc" ]] || { warn "env.removing_broken" "$pkg_dir"; rm -rf "$pkg_dir"; }
done
