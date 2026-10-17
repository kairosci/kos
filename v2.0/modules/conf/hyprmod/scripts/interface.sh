#!/usr/bin/env bash
set -euo pipefail

hyprmod_interface() {
    local module="$1" environment="$2" package file name target source stylesheet saved
    package=$(find "$environment/lib" -path '*/hyprmod/window.py' -type f -print -quit)
    [[ -n "$package" ]] || err "defaults.app_failed" "HyprMod interface"
    package=${package%/window.py}
    jq -e '.window | .width>=640 and .height>=480 and .minimumWidth>=320 and .minimumHeight>=320' "$module/data/interface.json" >/dev/null || err "session.validation_failed" "HyprMod interface"
    jq -e '.sidebar | .minimum>=160 and .maximum>=.minimum and .fraction>0 and .fraction<0.5 and .collapseBelow>=640' "$module/data/interface.json" >/dev/null || err "session.validation_failed" "HyprMod sidebar"
    jq -e '.content | .maximum>=.tightenBelow and .tightenBelow>=320 and .margin>=8 and .spacing>=8' "$module/data/interface.json" >/dev/null || err "session.validation_failed" "HyprMod content"
    if [[ ! -f "$environment/interface-complete" ]]; then
        patch --batch --fuzz=0 --dry-run -d "$package/.." -p1 < "$module/data/interface.patch" || err "defaults.app_failed" "HyprMod interface patch"
        patch --batch --fuzz=0 -d "$package/.." -p1 < "$module/data/interface.patch" || err "defaults.app_failed" "HyprMod interface patch"
        for file in "$package"/data/icons/hicolor/*/*/*symbolic.svg; do
            [[ -f "$file" ]] || continue
            name=${file##*/}
            name=${name%.svg}
            target=$(awk -F '\t' -v name="$name" '$1==name {print $2;exit}' "$module/data/icons.tsv")
            [[ -n "$target" ]] || target="$name"
            source=$(find /usr/share/icons/Adwaita -name "$target.svg" -type f -print -quit)
            [[ -n "$source" ]] || err "defaults.icons_failed"
            install_user_file "$source" "$file"
        done
        stylesheet=$(cat "$package/style.css")
        { printf '%s\n' "$stylesheet"; cat "$module/data/interface.css"; } | install_user_content "$package/style.css" 644
        "$environment/bin/python" -m compileall -q "$package" || err "defaults.app_failed" "HyprMod interface"
        install_user_content "$environment/interface-complete" 600 <<< complete
    fi
    install_user_file "$module/data/interface.json" "${XDG_CONFIG_HOME:-$HOME/.config}/hyprmod/interface.json" 600
    if [[ -S "${XDG_RUNTIME_DIR:-/nonexistent}/bus" ]]; then
        saved=$(dconf read /io/github/bluemancz/hyprmod/auto-save) || err "defaults.app_failed" "HyprMod settings"
        if [[ -z "$saved" ]]; then
            GSETTINGS_SCHEMA_DIR="$package/data" apply_user_gsettings "$module/data/settings.tsv" || err "defaults.app_failed" "HyprMod settings"
        fi
    fi
}
