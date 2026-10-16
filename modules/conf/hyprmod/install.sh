#!/usr/bin/env bash

install_hyprmod() {
    set -euo pipefail
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
    source "$PROJECT_DIR/scripts/lib/i18n.sh"
    source "$PROJECT_DIR/scripts/lib/userconf.sh"
    i18n_init
    local data="${XDG_DATA_HOME:-$HOME/.local/share}" config="${XDG_CONFIG_HOME:-$HOME/.config}" version environment stage icon
    [[ -f "$config/hypr/hyprland.lua" ]] || return 0
    local file
    for file in hyprland.lua bindings.lua hyprland-gui.lua; do
        [[ ! -L "$config/hypr/$file" ]] || err "session.validation_failed" "$file"
    done
    version=$({ sha256sum "$SCRIPT_DIR/data/requirements.lock"; pacman -Q python; } | sha256sum)
    environment="$data/os/hyprmod/${version:0:16}"
    if [[ ! -x "$environment/bin/hyprmod" || ! -f "$environment/complete" ]]; then
        if [[ ! -x "$environment/bin/python" ]]; then
            uv venv --system-site-packages --python /usr/bin/python --no-python-downloads "$environment"
        fi
        uv pip install --python "$environment/bin/python" --require-hashes --no-deps --no-build-isolation -r "$SCRIPT_DIR/data/requirements.lock"
    fi
    bash "$SCRIPT_DIR/scripts/check-runtime.sh" "$SCRIPT_DIR/data/native-minimums.tsv" "$environment" || err "defaults.app_failed" HyprMod
    icon=$(find "$environment/lib" -path '*/hyprmod/data/icons/hicolor/scalable/apps/io.github.bluemancz.hyprmod.svg' -type f -print -quit)
    [[ -n "$icon" ]] || err "defaults.app_failed" HyprMod
    [[ ! -e "$data/os/hyprmod/current" || -L "$data/os/hyprmod/current" ]] || err "session.validation_failed" HyprMod
    install_user_content "$environment/complete" 600 <<< "$version"
    stage=$(mktemp -d)
    HYPRMOD_STAGE="$stage"
    trap 'rm -rf -- "$HYPRMOD_STAGE"' EXIT
    mkdir -p "$stage/config/hypr"
    cp -a "$config/hypr/." "$stage/config/hypr/"
    if [[ ! -f "$stage/config/hypr/hyprland-gui.lua" ]]; then
        : > "$stage/config/hypr/hyprland-gui.lua"
    fi
    luac -p "$stage/config/hypr/hyprland-gui.lua" || err "session.validation_failed" HyprMod
    install_user_line "$stage/config/hypr/hyprland.lua" <<'LUA'
require("hyprland-gui")
LUA
    sed -i 's/"gnome-control-center"/"hyprmod"/g' "$stage/config/hypr/bindings.lua"
    install_shell_block "$stage/config/hypr/bindings.lua" '-- os hyprmod (managed)' '-- end os hyprmod (managed)' <<'LUA'
hl.unbind("SUPER + comma")
o.bind("SUPER + comma", "HyprMod", "hyprmod")
LUA
    XDG_CONFIG_HOME="$stage/config" XDG_DATA_HOME="$data" OS_HYPR_CONFIG_ROOT="$stage/config/hypr" \
        Hyprland --verify-config --config "$stage/config/hypr/hyprland.lua" > "$stage/validation.log" 2>&1 || {
        cat "$stage/validation.log"
        err "session.validation_failed" HyprMod
    }
    grep -qx 'config ok' "$stage/validation.log" || { cat "$stage/validation.log"; err "session.validation_failed" HyprMod; }
    install_user_file "$stage/config/hypr/hyprland-gui.lua" "$config/hypr/hyprland-gui.lua" 600
    install_user_file "$stage/config/hypr/hyprland.lua" "$config/hypr/hyprland.lua" 600
    install_user_file "$stage/config/hypr/bindings.lua" "$config/hypr/bindings.lua" 600
    ln -sfn "${environment##*/}" "$data/os/hyprmod/current"
    install_user_file "$SCRIPT_DIR/data/hyprmod" "$HOME/.local/bin/hyprmod" 755
    install_user_file "$SCRIPT_DIR/data/io.github.bluemancz.hyprmod.desktop" "$data/applications/io.github.bluemancz.hyprmod.desktop"
    install_user_file "$icon" "$data/icons/hicolor/scalable/apps/io.github.bluemancz.hyprmod.svg"
    log "gui.install_done" HyprMod
}

install_hyprmod "$@"
