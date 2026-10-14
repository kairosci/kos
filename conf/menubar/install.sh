#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
i18n_init

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
[[ -f "$CONFIG/shell.json" ]] || exit 0
[[ ! -L "$CONFIG/shell.json" && ! -L "$CONFIG/shell.toml" ]] || err "defaults.app_failed" "menubar"
staged=$(mktemp)
trap 'rm -f "$staged"' EXIT
jq --slurpfile order "$SCRIPT_DIR/data/layout.json" -f "$SCRIPT_DIR/data/layout.jq" "$CONFIG/shell.json" > "$staged" || err "defaults.app_failed" "menubar"
merge_user_ini "$SCRIPT_DIR/data/shell.toml" "$CONFIG/shell.toml" 600 || err "defaults.app_failed" "menubar"
install_user_content "$CONFIG/shell.json" 600 < "$staged" || err "defaults.app_failed" "menubar"
log "gui.install_done" "menubar"
