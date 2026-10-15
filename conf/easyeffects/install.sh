#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
i18n_init

PRESET=OS-Subwoofer
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/easyeffects"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/os/easyeffects"
for package in easyeffects calf lsp-plugins-lv2; do
    pacman -Q "$package" >/dev/null || err "defaults.app_failed" "$package"
done
jq -e '.output.plugins_order == ["filter#0", "bass_enhancer#0", "limiter#0"] and .output["limiter#0"].bypass == false and .output["limiter#0"]["threshold"] <= -2 and .output["limiter#0"]["gain-boost"] == true' \
    "$SCRIPT_DIR/data/$PRESET.json" >/dev/null || err "defaults.app_failed" "$PRESET"
mkdir -p "$STATE/before-setup"
chmod 700 "$STATE" "$STATE/before-setup"
for database in "$CONFIG/easyeffects/db/"*; do
    [[ -f "$database" ]] || continue
    backup="$STATE/before-setup/${database##*/}"
    [[ -f "$backup" ]] || install_user_file "$database" "$backup" 600 || err "defaults.app_failed" "EasyEffects backup"
done
install_user_file "$SCRIPT_DIR/data/$PRESET.json" "$DATA/output/$PRESET.json" 600 || err "defaults.app_failed" "$PRESET"
install_user_file "$SCRIPT_DIR/data/autostart.desktop" "$CONFIG/autostart/com.github.wwmm.easyeffects.desktop" 644 || err "defaults.app_failed" "EasyEffects autostart"

if [[ -S "${XDG_RUNTIME_DIR:-/nonexistent}/bus" ]]; then
    source "$SCRIPT_DIR/apply.sh"
    easyeffects_apply_preset
fi
log "gui.install_done" "EasyEffects"
