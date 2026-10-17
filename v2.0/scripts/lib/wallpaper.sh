#!/usr/bin/env bash

provision_wallpaper_dependencies() {
    local package
    local -a packages=()
    while IFS= read -r package; do
        [[ "$package" =~ ^[a-z0-9][a-z0-9-]*$ ]] || err "env.aur_invalid" "$package"
        packages+=("$package")
    done < "$PROJECT_DIR/data/component/wallpaper/packages.list"
    pacman -S --noconfirm --needed "${packages[@]}" || err "defaults.app_failed" "wallpaper"
}

provision_wallpaper_dependencies
