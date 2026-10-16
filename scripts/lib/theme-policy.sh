#!/usr/bin/env bash

Os::scripts::lib::theme_policy_sh::run() {

THEME_POLICY_FILE="${THEME_POLICY_FILE:-/usr/local/lib/os/excluded-themes.list}"
THEME_POLICY_ARCHIVE="${THEME_POLICY_ARCHIVE:-/var/lib/os/retired-themes}"

theme_policy_excluded() {
    [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ && -r "$THEME_POLICY_FILE" ]] || return 2
    grep -Fxq -- "$1" "$THEME_POLICY_FILE"
}

theme_policy_prune() {
    local root="$1" archive="$2" theme destination
    [[ -r "$THEME_POLICY_FILE" && ! -L "$root" && ! -L "$archive" ]] || return 1
    while IFS= read -r theme; do
        [[ "$theme" =~ ^[a-z0-9][a-z0-9-]*$ ]] || return 1
        [[ -e "$root/$theme" || -L "$root/$theme" ]] || continue
        install -d -m 700 "$archive" || return 1
        destination=$(mktemp -d "$archive/$theme.XXXXXX") || return 1
        mv -- "$root/$theme" "$destination/theme" || return 1
    done < "$THEME_POLICY_FILE"
}

theme_policy_apply() {
    local root="${THEME_POLICY_ROOT:-/usr/share/omarchy/themes}" home
    theme_policy_prune "$root" "$THEME_POLICY_ARCHIVE/system" || return 1
    for home in "${THEME_POLICY_HOMES:-/home}"/*; do
        [[ -d "$home" && ! -L "$home" ]] || continue
        [[ ! -L "$home/.config" && ! -L "$home/.config/os" ]] || return 1
        theme_policy_prune "$home/.config/os/themes" "$THEME_POLICY_ARCHIVE/users/${home##*/}" || return 1
    done
}

}

Os::scripts::lib::theme_policy_sh::run "$@"
