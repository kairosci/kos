#!/usr/bin/env bash

install_wallpapers() {
    set -euo pipefail
    local module project data theme directory
    module="$(dirname "$(dirname "$(readlink -f "$0")")")"
    project="$(dirname "$(dirname "$(dirname "$module")")")"
    source "$project/scripts/lib/i18n.sh"
    source "$project/scripts/lib/userconf.sh"
    locale_init
    data="${XDG_DATA_HOME:-$HOME/.local/share}"
    install_user_file "$project/data/component/wallpaper/krepo.png" "$data/os/desktop/wallpapers/krepo.png"
    install_user_file "$project/data/component/wallpaper/policy.json" "$data/os/desktop/wallpapers/policy.json"
    local runtime="$data/os/desktop/runtime" file
    for file in src/core/file.lua src/core/json.lua src/core/process.lua src/component/wallpaper/catalog.lua data/core/commands.json; do
        install_user_file "$project/$file" "$runtime/$file"
    done
    install_user_file "$module/scripts/wallpaper.sh" "$data/os/desktop/scripts/wallpaper.sh"
    for directory in "${OMARCHY_PATH:-/usr/share/omarchy}/themes/"* "${XDG_CONFIG_HOME:-$HOME/.config}/os/themes/"*; do
        [[ -f "$directory/colors.toml" ]] || continue
        theme="${directory##*/}"
        bash "$project/hooks/theme-set.d/wallpaper" "$theme"
    done
}

install_wallpapers "$@"
