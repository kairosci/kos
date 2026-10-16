#!/usr/bin/env bash

provision_hyprmod() {
    set -euo pipefail
    local package
    local -a packages=()
    while IFS= read -r package; do
        [[ "$package" =~ ^[a-z0-9][a-z0-9-]*$ ]] || err "env.aur_invalid" "$package"
        packages+=("$package")
    done < "$PROJECT_DIR/modules/conf/hyprmod/data/packages.list"
    pacman -S --noconfirm --needed "${packages[@]}" || err "defaults.app_failed" HyprMod
}

provision_hyprmod
