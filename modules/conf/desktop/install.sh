#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
i18n_init
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

for tool in micro disk; do
    remove_shell_block "$HOME/.bashrc" "# >>> os $tool >>>" "# <<< os $tool <<<"
done
for hook in micro-theme disk-theme btop-theme; do
    rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/hooks/theme-set.d/$hook"
done
install_user_file "$SCRIPT_DIR/data/mpv.desktop" "${XDG_DATA_HOME:-$HOME/.local/share}/applications/mpv.desktop"
install_user_file "$SCRIPT_DIR/data/branding/kmono.txt" "$CONFIG_HOME/omarchy/branding/screensaver.txt"
install_user_file "$SCRIPT_DIR/data/branding/kmono.txt" "$CONFIG_HOME/omarchy/branding/about.txt"
install_user_file "$SCRIPT_DIR/data/fastfetch/config.jsonc" "$CONFIG_HOME/fastfetch/config.jsonc"
install_user_file "$SCRIPT_DIR/data/wallpapers/krepo.png" "${XDG_DATA_HOME:-$HOME/.local/share}/os/desktop/wallpapers/krepo.png"
WALLPAPER_THEME=""
WALLPAPER_THEME_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/theme.name"
if [[ -f "$WALLPAPER_THEME_FILE" ]]; then
    WALLPAPER_THEME="$(cat "$WALLPAPER_THEME_FILE")"
fi
if [[ -n "$WALLPAPER_THEME" ]]; then
    bash "$PROJECT_DIR/hooks/theme-set.d/wallpaper" "$WALLPAPER_THEME"
fi
rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/screensaver-off"
log "gui.install_done" "desktop"
