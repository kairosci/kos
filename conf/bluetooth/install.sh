#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck source=/dev/null
source "$PROJECT_DIR/scripts/lib/i18n.sh"
# shellcheck source=/dev/null
source "$PROJECT_DIR/scripts/lib/userconf.sh"
i18n_init

SOURCE_DIR="${OMARCHY_PATH:-/usr/share/omarchy}/shell/plugins/panels/bluetooth"
DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/omaconf.bluetooth"
SHELL_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"

[[ -r "$SOURCE_DIR/Panel.qml" && -r "$SOURCE_DIR/manifest.json" && -r "$SOURCE_DIR/Model.js" ]] || err "defaults.app_failed" bluetooth
[[ -f "$SHELL_CONFIG" ]] || err "defaults.app_failed" bluetooth
[[ $(grep -Fc 'readonly property var adapter: Bluetooth.defaultAdapter' "$SOURCE_DIR/Panel.qml") == 1 ]] || err "defaults.app_failed" bluetooth

panel=$(awk -v snippet="$SCRIPT_DIR/data/state.qml" '
    { gsub(/root\.adapter\.enabled/, "root.adapterPowered"); gsub(/adapter\.enabled/, "root.adapterPowered"); print }
    /readonly property var adapter: Bluetooth.defaultAdapter/ {
        while ((result = getline line < snippet) > 0) print line
        if (result < 0) exit 1
        close(snippet)
    }
' "$SOURCE_DIR/Panel.qml")
manifest=$(jq '.id = "omaconf.bluetooth" | .omarchy.clonedFrom = "omarchy.bluetooth"' "$SOURCE_DIR/manifest.json")
config=$(jq 'walk(if type == "object" and .id? == "omarchy.bluetooth" then .id = "omaconf.bluetooth" else . end)' "$SHELL_CONFIG")
install_user_content "$DEST_DIR/Panel.qml" <<< "$panel"
install_user_file "$SOURCE_DIR/Model.js" "$DEST_DIR/Model.js"
install_user_content "$DEST_DIR/manifest.json" <<< "$manifest"
install_user_content "$SHELL_CONFIG" <<< "$config"
