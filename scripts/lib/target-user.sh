#!/usr/bin/env bash

target_user_resolve() {
    local candidate=""

    candidate="${SUDO_USER:-}"
    if [[ -z "$candidate" ]] && [[ "${PKEXEC_UID:-}" =~ ^[0-9]+$ ]]; then
        candidate=$(id -nu "$PKEXEC_UID" 2>/dev/null || printf '')
    fi
    if [[ -z "$candidate" || "$candidate" == root ]] || ! id "$candidate" &>/dev/null; then
        candidate=$(getent group wheel 2>/dev/null | cut -d: -f4 | cut -d, -f1)
    fi
    if [[ -z "$candidate" || "$candidate" == root ]] || ! id "$candidate" &>/dev/null; then
        candidate=$(basename "$(find /home -mindepth 1 -maxdepth 1 -type d 2>/dev/null | tail -1)")
    fi

    if [[ -z "$candidate" || "$candidate" == root ]] || ! id "$candidate" &>/dev/null; then
        return 1
    fi
    printf '%s\n' "$candidate"
}

target_home_resolve() {
    local user="$1" home=""

    home=$(getent passwd "$user" 2>/dev/null | cut -d: -f6)
    [[ -n "$home" ]] || home="/home/$user"
    if [[ ! -d "$home" ]]; then
        return 1
    fi
    printf '%s\n' "$home"
}

target_uid_resolve() {
    local user="$1" uid=""

    uid=$(id -u "$user" 2>/dev/null || printf '')
    if [[ ! "$uid" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    printf '%s\n' "$uid"
}
