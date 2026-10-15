#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home" XDG_CONFIG_HOME="$SANDBOX/config" OS_LANG=en
CONFIG="$XDG_CONFIG_HOME/omarchy"
INSTALLER="$PROJECT_DIR/modules/conf/menubar/install.sh"
mkdir -p "$CONFIG"
cat > "$CONFIG/shell.json" <<'JSON'
{"idle":{"lock":321},"bar":{"position":"bottom","transparent":true,"layout":{"left":["omarchy.menu","omarchy.workspaces",{"id":"personal.widget","custom":7}],"center":["omarchy.keyboard-layout"],"right":[{"id":"omarchy.clock","format":"HH:mm"},{"id":"omaconf.power","custom":9},"omarchy.tray"]}}}
JSON
printf '[bar]\nsize-horizontal  = 26\ntext = "#abcdef"\n[font]\nbase-size = 12\n' > "$CONFIG/shell.toml"
test_section "Native Menubar Configuration"
assert_true "menubar module installs" "bash '$INSTALLER'"
assert_true "clock moves to center with its preferences intact" "jq -e '.bar.layout.center == [{id:\"omarchy.clock\",format:\"HH:mm\"}] and .bar.centerAnchor == \"omarchy.clock\"' '$CONFIG/shell.json'"
assert_true "personal widgets keep their section and settings" "jq -e '.bar.layout.left[-1] == {id:\"personal.widget\",custom:7} and .bar.layout.right[-1] == {id:\"omaconf.power\",custom:9}' '$CONFIG/shell.json'"
assert_true "bar keeps its screen edge and unrelated idle settings" "jq -e '.bar.position == \"bottom\" and .idle.lock == 321 and .bar.transparent == false' '$CONFIG/shell.json'"
assert_true "layout preserves the exact existing widget count" "jq -e '[.bar.layout[][]] | length == 7' '$CONFIG/shell.json'"
assert_file_contains_literal "font overrides survive dimension changes" "$CONFIG/shell.toml" 'base-size = 12'
assert_file_contains_literal "palette overrides survive dimension changes" "$CONFIG/shell.toml" 'text = "#abcdef"'
assert_true "whitespace around TOML keys does not duplicate bar dimensions" "[[ \$(grep -Ec '^[[:space:]]*size-horizontal[[:space:]]*=' '$CONFIG/shell.toml') == 1 ]] && grep -qx 'size-horizontal=34' '$CONFIG/shell.toml'"
assert_file_contains_literal "original TOML is backed up" "$CONFIG/shell.toml.bak" 'size-horizontal  = 26'
before=$(sha256sum "$CONFIG/shell.json" "$CONFIG/shell.toml")
assert_true "bar installation is idempotent" "bash '$INSTALLER'; [[ \"\$(sha256sum '$CONFIG/shell.json' '$CONFIG/shell.toml')\" == '$before' ]]"
jq '.bar.layout.left += ["omarchy.menu"]' "$CONFIG/shell.json" > "$SANDBOX/duplicate.json"
cp "$SANDBOX/duplicate.json" "$CONFIG/shell.json"
assert_false "duplicate widgets fail before modifying either config" "bash '$INSTALLER'"
assert_true "failed layout preserves both configuration files" "cmp -s '$SANDBOX/duplicate.json' '$CONFIG/shell.json' && grep -qx 'size-horizontal=34' '$CONFIG/shell.toml'"
test_summary
