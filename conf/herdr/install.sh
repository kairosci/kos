#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SHARE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/omarchy"
BINDINGS="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/bindings.lua"
MARK_BEGIN="-- os-herdr-keys (managed)"
MARK_END="-- end os-herdr-keys (managed)"
MENU_SRC="$SCRIPT_DIR/data/herdr-keybindings-menu"
MENU_PATH="$SHARE_DIR/herdr-keybindings-menu"

PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
I18N_LIB="$PROJECT_DIR/scripts/lib"
# shellcheck source=/dev/null
source "$I18N_LIB/i18n.sh"
# shellcheck source=/dev/null
source "$I18N_LIB/userconf.sh"

i18n_init

install_user_file "$MENU_SRC" "$MENU_PATH" 755

if [[ -f "$BINDINGS" ]]; then
    install_shell_block "$BINDINGS" "$MARK_BEGIN" "$MARK_END" << LUAEOF
hl.unbind("SUPER + CTRL + K")
o.bind("SUPER + CTRL + K", "Herdr keybindings", "$MENU_PATH")
LUAEOF
else
    warn "herdr.bind_skipped" "$HOME"
fi

log "install.herdr_done"
