#!/usr/bin/env bash

Os::modules::conf::micro::install_sh::run() {
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
i18n_init

MICRO_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/micro"
MICRO_PLUGINS="$MICRO_CONFIG/plug"
MICRO_FILEMANAGER="$MICRO_PLUGINS/filemanager"
MICRO_SETTINGS="$MICRO_CONFIG/settings.json"
[[ ! -L "$MICRO_CONFIG" && ! -L "$MICRO_PLUGINS" && ! -L "$MICRO_FILEMANAGER" && ! -L "$MICRO_SETTINGS" ]] || err "defaults.app_failed" "micro"

if [[ -e "$MICRO_FILEMANAGER" ]]; then
    rm -rf -- "$MICRO_FILEMANAGER" || err "defaults.app_failed" "micro filemanager"
fi

if [[ -f "$MICRO_SETTINGS" ]]; then
    staged=$(mktemp) || err "defaults.app_failed" "micro settings"
    trap 'rm -f "$staged"' EXIT
    jq -e 'if type == "object" then del(."filemanager.openonstart") else error("settings must be a JSON object") end' "$MICRO_SETTINGS" > "$staged" || err "defaults.app_failed" "micro settings"
    install_user_content "$MICRO_SETTINGS" 600 < "$staged" || err "defaults.app_failed" "micro settings"
fi
log "gui.install_done" "micro"

}

Os::modules::conf::micro::install_sh::run "$@"
