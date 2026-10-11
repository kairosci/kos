#!/usr/bin/env bash

set -euo pipefail

log "env.sync"
OMARCHY_ALLOW_DIRECT_PACMAN=1 pacman -Syu --noconfirm || err "env.sync_skipped"

log "env.fixing_broken"
for pkg_dir in /var/lib/pacman/local/*/; do
    [[ -d "$pkg_dir" ]] || continue
    [[ -f "$pkg_dir/desc" ]] || { warn "env.removing_broken" "$pkg_dir"; rm -rf "$pkg_dir"; }
done

aur_package_artifact() {
    local directory="$1" package="$2" artifact name
    for artifact in "$directory/$package-"*.pkg.tar.*; do
        [[ -f "$artifact" && "$artifact" != *.sig ]] || continue
        name=$(pacman -Qpq "$artifact") || return 1
        if [[ "$name" == "$package" ]]; then
            printf '%s\n' "$artifact"
            return 0
        fi
    done
    return 1
}

aur_source_dependencies() {
    awk -v arch="$2" '$1 == "depends" || $1 == "makedepends" || $1 == "depends_" arch || $1 == "makedepends_" arch { print $3 }' "$1"
}

aur_verified_install() {
    local pkg="$1" tmp f srcinfo dependency dependency_metadata missing status=0
    local -a dependencies=() missing_dependencies=()
    [[ -n "$pkg" ]] || err "env.aur_empty"
    [[ "$pkg" =~ ^[a-zA-Z0-9._-]+$ ]] || err "env.aur_invalid" "$pkg"
    pacman -S --noconfirm --needed base-devel git wget
    tmp=$(mktemp -d)
    chmod 700 "$tmp"
    chown "$PRIMARY_USER":"$PRIMARY_USER" "$tmp"
    sudo -u "$PRIMARY_USER" bash -c \
        "cd '$tmp' && git clone --quiet --depth 1 https://aur.archlinux.org/$pkg.git src && cd src && \
         { grep -q '^validpgpkeys=' PKGBUILD || \
           { grep -qE '^(sha256sums|sha512sums|b2sums|sha256sums_x86_64)=' PKGBUILD && ! grep -q 'SKIP' PKGBUILD && \
             grep -qE '^#[[:space:]]*Maintainer[[:space:]]*: [^<]+ <([^ ]+@[^ ]+|contact: https://[^ >]+)>' PKGBUILD; }; }" || \
        err "env.aur_no_integrity" "$pkg"
    srcinfo="$tmp/srcinfo"
    sudo -u "$PRIMARY_USER" bash -c 'cd "$1" && makepkg --printsrcinfo > "$2"' bash "$tmp/src" "$srcinfo" || {
        rm -rf "$tmp"
        err "env.aur_verify_failed" "$pkg"
    }
    dependency_metadata=$(aur_source_dependencies "$srcinfo" "$(uname -m)") || {
        rm -rf "$tmp"
        err "env.aur_verify_failed" "$pkg"
    }
    while IFS= read -r dependency; do
        [[ -n "$dependency" ]] || continue
        [[ "$dependency" =~ ^[a-zA-Z0-9@._+-]+([\<\>\=]+[a-zA-Z0-9:._+~-]+)?$ ]] || {
            rm -rf "$tmp"
            err "env.aur_invalid" "$dependency"
        }
        dependencies+=("$dependency")
    done <<< "$dependency_metadata"
    if ((${#dependencies[@]})); then
        missing=$(pacman -T "${dependencies[@]}") || status=$?
        if [[ $status -ne 0 && $status -ne 127 ]]; then
            rm -rf "$tmp"
            err "env.aur_verify_failed" "$pkg"
        fi
        if [[ -n "$missing" ]]; then
            mapfile -t missing_dependencies <<< "$missing"
            pacman -S --noconfirm --needed --asdeps "${missing_dependencies[@]}" || {
                rm -rf "$tmp"
                err "env.aur_verify_failed" "$pkg"
            }
        fi
    fi
    sudo -u "$PRIMARY_USER" bash -c \
        "cd '$tmp/src' && makepkg --noconfirm" || {
        rm -rf "$tmp"
        err "env.aur_verify_failed" "$pkg"
    }
    f=$(aur_package_artifact "$tmp/src" "$pkg") || { rm -rf "$tmp"; err "env.aur_no_artifact" "$pkg"; }
    pacman -U --noconfirm "$f"
    rm -rf "$tmp"
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
    if [[ -n "${OMACONF_LANG:-}" ]]; then _env+=("OMACONF_LANG=$OMACONF_LANG"); fi
    if [[ -n "${OMACONF_FORCE_TZ:-}" ]]; then _env+=("OMACONF_FORCE_TZ=$OMACONF_FORCE_TZ"); fi
    local session_env entry
    if [[ -n "$bus" ]] && session_env=$(sudo -u "$user" env "XDG_RUNTIME_DIR=$runtime" "DBUS_SESSION_BUS_ADDRESS=$bus" systemctl --user show-environment); then
        while IFS= read -r entry; do
            case "$entry" in
                WAYLAND_DISPLAY=*|DISPLAY=*|HYPRLAND_INSTANCE_SIGNATURE=*|XDG_CURRENT_DESKTOP=*) _env+=("$entry") ;;
            esac
        done <<< "$session_env"
    fi
    sudo -u "$user" env -u XDG_SESSION_DESKTOP -u DESKTOP_SESSION \
        -u SUDO_USER -u SUDO_UID -u SUDO_GID -u PKEXEC_UID "${_env[@]}" "$@"
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
