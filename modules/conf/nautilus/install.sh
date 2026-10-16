#!/usr/bin/env bash

Os::modules::conf::nautilus::install_sh::run() {
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
i18n_init
apply_user_gsettings "$SCRIPT_DIR/data/settings.tsv"
log "gui.install_done" "Nautilus"

}

Os::modules::conf::nautilus::install_sh::run "$@"
