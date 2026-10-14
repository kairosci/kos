#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/test_lib.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home" XDG_CONFIG_HOME="$SANDBOX/home/.config"
export OMARCHY_PATH="$SANDBOX/upstream"
source_dir="$OMARCHY_PATH/shell/plugins/panels/power"
mkdir -p "$source_dir" "$XDG_CONFIG_HOME/omarchy"
printf 'Panel { moduleName: "omarchy.power"; ipcTarget: "omarchy.power" }\n' > "$source_dir/Panel.qml"
cat > "$source_dir/Model.js" <<'JS'
function chargeThresholdActive(d, onBattery, states) {
  if (!d.isPresent || onBattery) return false
  if (d.state === states.PendingCharge) return true
  if (d.state === states.FullyCharged && d.percentage < 0.99) return true
  if (d.state !== states.Charging || d.percentage >= 0.99) return false
  return Number(d.changeRate || 0) <= 0.2 || Number(d.timeToFull || 0) >= 8 * 60 * 60
}
JS
printf '{"id":"omarchy.power"}\n' > "$source_dir/manifest.json"
printf '{"bar":{"layout":{"right":[{"id":"omarchy.audio"},{"id":"omarchy.power","showPercentage":true}]}},"idle":{"lock":300}}\n' > "$XDG_CONFIG_HOME/omarchy/shell.json"
installer="$SCRIPT_DIR/../conf/power/install.sh"
plugin="$XDG_CONFIG_HOME/omarchy/plugins/omaconf.power"
test_section "Power charging state"
assert_true "installer generates the power clone" 'bash "$installer" && [[ -f "$plugin/Model.js" ]]'
assert_true "clone preserves the original panel and IPC" 'cmp -s "$source_dir/Panel.qml" "$plugin/Panel.qml" && jq -e '\''.omarchy.clonedFrom == "omarchy.power"'\'' "$plugin/manifest.json"'
assert_file_not_contains "slow charging is not treated as a threshold pause" "$plugin/Model.js" 'changeRate|timeToFull'
assert_file_contains_literal "pending charge remains a threshold pause" "$plugin/Model.js" 'if (d.state === states.PendingCharge) return true'
assert_true "bar position and percentage setting survive" 'jq -e '\''.bar.layout.right[0].id == "omarchy.audio" and .bar.layout.right[1].id == "omaconf.power" and .bar.layout.right[1].showPercentage and .idle.lock == 300'\'' "$XDG_CONFIG_HOME/omarchy/shell.json"'
first_hash=$(sha256sum "$plugin/Model.js" "$XDG_CONFIG_HOME/omarchy/shell.json")
assert_true "repeated installation is idempotent" 'bash "$installer" && [[ "$first_hash" == "$(sha256sum "$plugin/Model.js" "$XDG_CONFIG_HOME/omarchy/shell.json")" ]]'
printf 'function chargeThresholdActive() { return false }\n' > "$source_dir/Model.js"
assert_false "unsupported upstream fails before installation" 'bash "$installer"'
assert_true "failed migration preserves previous state" '[[ "$first_hash" == "$(sha256sum "$plugin/Model.js" "$XDG_CONFIG_HOME/omarchy/shell.json")" ]]'
test_summary
