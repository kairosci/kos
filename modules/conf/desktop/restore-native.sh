#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
i18n_init
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="${XDG_STATE_HOME:-$HOME/.local/state}/os/desktop-defaults"
UPSTREAM="${OMARCHY_PATH:-/usr/share/omarchy}/config"
for file in kitty/kitty.conf alacritty/alacritty.toml ghostty/config foot/foot.ini; do
    [[ -r "$UPSTREAM/$file" ]] || err "defaults.app_failed" "${file%/*}"
    if [[ -f "$CONFIG_HOME/$file" && ! -e "$BACKUP/$file" ]]; then
        mkdir -p "$BACKUP/${file%/*}"
        chmod 700 "$BACKUP" "$BACKUP/${file%/*}"
        cp -p "$CONFIG_HOME/$file" "$BACKUP/$file"
    fi
    install_user_file "$UPSTREAM/$file" "$CONFIG_HOME/$file"
done
for asset in screensaver.txt about.txt; do
    source="$SCRIPT_DIR/data/branding/kmono.txt"
    file="omarchy/branding/$asset"
    [[ -r "$source" ]] || err "defaults.app_failed" branding
    if [[ -f "$CONFIG_HOME/$file" && ! -e "$BACKUP/$file" ]]; then
        mkdir -p "$BACKUP/${file%/*}"
        chmod 700 "$BACKUP" "$BACKUP/omarchy" "$BACKUP/${file%/*}"
        cp -p "$CONFIG_HOME/$file" "$BACKUP/$file"
    fi
    install_user_file "$source" "$CONFIG_HOME/$file"
done
install_user_file "$SCRIPT_DIR/data/fastfetch/config.jsonc" "$CONFIG_HOME/fastfetch/config.jsonc"
rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/screensaver-off"
log "recovery.terminals_ready" "$BACKUP"
