#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"

SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/home/.config/micro"
export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
touch "$HOME/.bashrc"
mkdir -p "$XDG_CONFIG_HOME/micro/plug/filemanager" "$XDG_CONFIG_HOME/micro/plug/other"
printf '%s\n' 'VERSION = "old"' > "$XDG_CONFIG_HOME/micro/plug/filemanager/filemanager.lua"
printf '%s\n' 'VERSION = "keep"' > "$XDG_CONFIG_HOME/micro/plug/other/other.lua"
printf '%s\n' '{"filemanager.openonstart": true, "tabsize": 4, "softwrap": true}' > "$XDG_CONFIG_HOME/micro/settings.json"

assert_true "Micro installer removes the obsolete filemanager plugin" "bash '$PROJECT_DIR/modules/conf/micro/install.sh'"
assert_false "Micro no longer installs the filemanager plugin" "[[ -e '$XDG_CONFIG_HOME/micro/plug/filemanager' ]]"
assert_true "Micro settings preserve unrelated preferences" "jq -e '.tabsize == 4 and .softwrap == true and has(\"filemanager.openonstart\") == false' '$XDG_CONFIG_HOME/micro/settings.json'"
assert_file_contains_literal "Micro installer preserves unrelated plugins" "$XDG_CONFIG_HOME/micro/plug/other/other.lua" 'VERSION = "keep"'
assert_true "Micro installer is idempotent" "before=\$(sha256sum '$XDG_CONFIG_HOME/micro/settings.json' '$HOME/.bashrc'); bash '$PROJECT_DIR/modules/conf/micro/install.sh'; [[ \"\$before\" == \"\$(sha256sum '$XDG_CONFIG_HOME/micro/settings.json' '$HOME/.bashrc')\" ]]"
assert_true "Micro settings use private permissions" "[[ \$(stat -c %a '$XDG_CONFIG_HOME/micro/settings.json') == 600 ]]"

mv "$XDG_CONFIG_HOME/micro/settings.json" "$SANDBOX/settings.json"
ln -s "$SANDBOX/settings.json" "$XDG_CONFIG_HOME/micro/settings.json"
assert_false "Micro installer rejects settings symlinks" "bash '$PROJECT_DIR/modules/conf/micro/install.sh'"

test_summary
