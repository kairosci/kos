#!/usr/bin/env bash

Os::modules::conf::onlyoffice::install_sh::run() {
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
i18n_init

merge_user_ini "$SCRIPT_DIR/data/DesktopEditors.conf" "${XDG_CONFIG_HOME:-$HOME/.config}/onlyoffice/DesktopEditors.conf" 600
log "gui.install_done" "OnlyOffice"

}

Os::modules::conf::onlyoffice::install_sh::run "$@"
