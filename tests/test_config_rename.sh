#!/usr/bin/env bash

Os::tests::test_config_rename_sh::run() {
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
WORK_DIR=$(mktemp -d)
trap 'rm -rf -- "$WORK_DIR"' EXIT
make_home() {
    local home="$WORK_DIR/$1"
    rm -rf "$home"
    mkdir -p "$home/.config"
    printf '%s' "$home"
}
HOME_A=$(make_home home-a)
mkdir -p "$HOME_A/.config/omarchy/plugins/os.menu" "$HOME_A/.config/omarchy/extensions"
printf 'plugin\n' > "$HOME_A/.config/omarchy/plugins/os.menu/Menu.qml"
printf 'menu\n' > "$HOME_A/.config/omarchy/extensions/os-menu.json"
assert_true "migration moves user content under the os directory" "migrate_user_config_dir '$HOME_A' && [[ -f '$HOME_A/.config/os/plugins/os.menu/Menu.qml' && -f '$HOME_A/.config/os/extensions/os-menu.json' ]]"
assert_true "migration leaves a compatibility link behind" "[[ -L '$HOME_A/.config/omarchy' && \"\$(readlink '$HOME_A/.config/omarchy')\" == os ]]"
assert_true "legacy paths resolve through the compatibility link" "[[ -f '$HOME_A/.config/omarchy/plugins/os.menu/Menu.qml' ]]"
assert_true "migration is idempotent" "migrate_user_config_dir '$HOME_A' && [[ -f '$HOME_A/.config/os/plugins/os.menu/Menu.qml' ]]"
HOME_B=$(make_home home-b)
assert_true "migration creates the os directory on fresh homes" "migrate_user_config_dir '$HOME_B' && [[ -d '$HOME_B/.config/os' && -L '$HOME_B/.config/omarchy' ]]"
HOME_C=$(make_home home-c)
mkdir -p "$HOME_C/.config/omarchy"
assert_true "migration handles an empty legacy directory" "migrate_user_config_dir '$HOME_C' && [[ -d '$HOME_C/.config/os' && ! -e '$HOME_C/.config/os/Menu.qml' ]]"
HOME_D=$(make_home home-d)
ln -s elsewhere "$HOME_D/.config/omarchy"
assert_true "migration refuses a foreign link" "! migrate_user_config_dir '$HOME_D'"
assert_true "session installer migrates before reading" "grep -q 'migrate_user_config_dir' '$PROJECT_DIR/modules/conf/session/install.sh'"
assert_true "menu model reads the renamed user menu" "grep -q '/os/extensions/os-menu.json' '$PROJECT_DIR/modules/conf/session/scripts/prepare-menu.lua'"
assert_true "theming installs hooks under the os directory" "grep -q '.config/os/hooks/theme-set.d' '$PROJECT_DIR/scripts/lib/modules/30-theming.sh'"
assert_true "theme policy prunes user themes under the os directory" "grep -q '.config/os/themes' '$PROJECT_DIR/scripts/lib/theme-policy.sh'"
test_summary

}

Os::tests::test_config_rename_sh::run "$@"
