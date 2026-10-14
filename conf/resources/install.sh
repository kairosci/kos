#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
i18n_init
schemas=$(gsettings list-schemas)
schema=net.nokyan.Resources
if grep -Fxq org.gnome.Resources <<< "$schemas"; then
    schema=org.gnome.Resources
fi
apply_user_gsettings "$SCRIPT_DIR/data/settings.tsv" "$schema"
if [[ "$schema" == net.nokyan.Resources ]]; then
    apply_user_gsettings "$SCRIPT_DIR/data/legacy-settings.tsv"
fi
log "gui.install_done" "${SCRIPT_DIR##*/}"
