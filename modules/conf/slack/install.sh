#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
locale_init
app=${SCRIPT_DIR##*/}
install_user_electron_launcher "/usr/share/applications/$app.desktop" "${XDG_DATA_HOME:-$HOME/.local/share}/applications/$app.desktop"
update-desktop-database "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
log "gui.install_done" "$app"
