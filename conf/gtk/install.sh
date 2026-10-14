#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
i18n_init
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
install_user_file "$SCRIPT_DIR/data/tiling.lua" "$CONFIG_HOME/hypr/os-gtk.lua"
if [[ -f "$CONFIG_HOME/hypr/hyprland.lua" ]]; then
    install_shell_block "$CONFIG_HOME/hypr/hyprland.lua" '-- os gtk tiling (managed)' '-- end os gtk tiling (managed)' <<'LUA'
require("os-gtk")
LUA
fi
for asset in "$SCRIPT_DIR/data/nerd-icons/"*; do
    install_user_file "$asset" "$CONFIG_HOME/omarchy/nerd-icons/${asset##*/}"
done
legacy_hook="$CONFIG_HOME/omarchy/hooks/theme-set.d/zz-unified-icons"
if [[ -f "$legacy_hook" ]] && grep -qF 'exec /usr/bin/python "$HOME/.config/omarchy/gtk-unified.py"' "$legacy_hook"; then
    install_user_file "$legacy_hook" "$CONFIG_HOME/omarchy/migrations/gtk-unified/theme-set"
    rm -f "$legacy_hook"
    legacy_generator="$CONFIG_HOME/omarchy/gtk-unified.py"
    if [[ -f "$legacy_generator" ]]; then
        install_user_file "$legacy_generator" "$CONFIG_HOME/omarchy/migrations/gtk-unified/generator.py"
        rm -f "$legacy_generator"
    fi
    legacy_update="$CONFIG_HOME/omarchy/hooks/post-update.d/zz-unified-icons"
    if [[ -f "$legacy_update" ]] && grep -qF 'exec "$HOME/.config/omarchy/hooks/theme-set.d/zz-unified-icons"' "$legacy_update"; then
        install_user_file "$legacy_update" "$CONFIG_HOME/omarchy/migrations/gtk-unified/post-update"
        rm -f "$legacy_update"
    fi
fi
apply_user_gsettings "$SCRIPT_DIR/data/settings.tsv"
log "gui.install_done" "GTK"
