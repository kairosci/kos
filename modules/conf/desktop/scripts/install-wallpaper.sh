#!/usr/bin/env bash

install_wallpapers() {
    set -euo pipefail
    local module project data theme directory
    module="$(dirname "$(dirname "$(readlink -f "$0")")")"
    project="$(dirname "$(dirname "$(dirname "$module")")")"
    source "$project/scripts/lib/i18n.sh"
    source "$project/scripts/lib/userconf.sh"
    i18n_init
    data="${XDG_DATA_HOME:-$HOME/.local/share}"
    install_user_file "$module/data/wallpapers/krepo.png" "$data/os/desktop/wallpapers/krepo.png"
    install_user_file "$module/data/wallpapers/policy.json" "$data/os/desktop/wallpapers/policy.json"
    install_user_file "$module/scripts/wallpaper.sh" "$data/os/desktop/scripts/wallpaper.sh"
    for directory in "${OMARCHY_PATH:-/usr/share/omarchy}/themes/"* "${XDG_CONFIG_HOME:-$HOME/.config}/os/themes/"*; do
        [[ -f "$directory/colors.toml" ]] || continue
        theme="${directory##*/}"
        bash "$project/hooks/theme-set.d/wallpaper" "$theme"
    done
}

install_wallpapers "$@"
