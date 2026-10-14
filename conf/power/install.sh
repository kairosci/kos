#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck source=/dev/null
source "$PROJECT_DIR/scripts/lib/i18n.sh"
# shellcheck source=/dev/null
source "$PROJECT_DIR/scripts/lib/userconf.sh"
i18n_init

SOURCE_DIR="${OMARCHY_PATH:-/usr/share/omarchy}/shell/plugins/panels/power"
DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/omaconf.power"
SHELL_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
HEURISTIC='  return Number(d.changeRate || 0) <= 0.2 || Number(d.timeToFull || 0) >= 8 * 60 * 60'

[[ -r "$SOURCE_DIR/Panel.qml" && -r "$SOURCE_DIR/manifest.json" && -r "$SOURCE_DIR/Model.js" ]] || err "defaults.app_failed" power
[[ -f "$SHELL_CONFIG" ]] || err "defaults.app_failed" power
[[ $(grep -Fxc "$HEURISTIC" "$SOURCE_DIR/Model.js") == 1 ]] || err "defaults.app_failed" power

model=$(awk -v heuristic="$HEURISTIC" '$0 == heuristic { print "  return false"; next } { print }' "$SOURCE_DIR/Model.js")
manifest=$(jq '.id = "omaconf.power" | .omarchy.clonedFrom = "omarchy.power"' "$SOURCE_DIR/manifest.json")
config=$(jq 'walk(if type == "object" and .id? == "omarchy.power" then .id = "omaconf.power" else . end)' "$SHELL_CONFIG")
install_user_file "$SOURCE_DIR/Panel.qml" "$DEST_DIR/Panel.qml"
install_user_content "$DEST_DIR/Model.js" <<< "$model"
install_user_content "$DEST_DIR/manifest.json" <<< "$manifest"
install_user_content "$SHELL_CONFIG" <<< "$config"
