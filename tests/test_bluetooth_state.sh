#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/test_lib.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home" XDG_CONFIG_HOME="$SANDBOX/home/.config"
export OMARCHY_PATH="$SANDBOX/upstream"
source_dir="$OMARCHY_PATH/shell/plugins/panels/bluetooth"
mkdir -p "$source_dir" "$XDG_CONFIG_HOME/omarchy"
cat > "$source_dir/Panel.qml" <<'QML'
Panel {
  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool checked: root.adapter && root.adapter.enabled
  readonly property string status: adapter.enabled ? "on" : "off"
}
QML
printf '{}\n' > "$source_dir/Model.js"
printf '{"id":"omarchy.bluetooth"}\n' > "$source_dir/manifest.json"
printf '{"bar":{"layout":{"right":[{"id":"omarchy.bluetooth"},{"id":"omarchy.audio"}]}},"idle":{"lock":300}}\n' > "$XDG_CONFIG_HOME/omarchy/shell.json"
installer="$SCRIPT_DIR/../conf/bluetooth/install.sh"
plugin="$XDG_CONFIG_HOME/omarchy/plugins/omaconf.bluetooth"
test_section "Bluetooth state reconciliation"
assert_true "installer generates a local clone" 'bash "$installer" && [[ -f "$plugin/Panel.qml" ]]'
assert_true "clone preserves IPC routing" 'jq -e '\''.omarchy.clonedFrom == "omarchy.bluetooth"'\'' "$plugin/manifest.json"'
assert_true "power query addresses the current BlueZ adapter with a timeout" 'grep -q '\''"--timeout=2", "get-property"'\'' "$plugin/Panel.qml" && grep -q '\''powerProbe.queriedPath = root.adapter.dbusPath'\'' "$plugin/Panel.qml"'
assert_true "all display bindings use reconciled state" 'grep -q '\''root.adapter && root.adapterPowered'\'' "$plugin/Panel.qml" && grep -q '\''status: root.adapterPowered'\'' "$plugin/Panel.qml"'
assert_true "late results cannot overwrite a replacement adapter" 'grep -q '\''powerProbe.queriedPath === root.adapter.dbusPath'\'' "$plugin/Panel.qml"'
assert_true "failed probes invalidate cached state" 'grep -q '\''exitCode !== 0 || exitStatus !== 0'\'' "$plugin/Panel.qml"'
assert_true "bar position and unrelated settings survive" 'jq -e '\''.bar.layout.right[0].id == "omaconf.bluetooth" and .bar.layout.right[1].id == "omarchy.audio" and .idle.lock == 300'\'' "$XDG_CONFIG_HOME/omarchy/shell.json"'
first_hash=$(sha256sum "$plugin/Panel.qml" "$XDG_CONFIG_HOME/omarchy/shell.json")
assert_true "repeated installation is idempotent" 'bash "$installer" && [[ "$first_hash" == "$(sha256sum "$plugin/Panel.qml" "$XDG_CONFIG_HOME/omarchy/shell.json")" ]]'
printf 'Panel {}\n' > "$source_dir/Panel.qml"
assert_false "unsupported upstream structure fails before replacing the plugin" 'bash "$installer"'
assert_true "failed migration preserves previous state" '[[ "$first_hash" == "$(sha256sum "$plugin/Panel.qml" "$XDG_CONFIG_HOME/omarchy/shell.json")" ]]'
test_summary
