#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SHELL_PLUGINS_MODULE="$PROJECT_DIR/scripts/lib/modules/35-shell-plugins.sh"
CLICONF_DATA="$PROJECT_DIR/data/component/terminal/help"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Config Validity & Placement Regression"

assert_file_contains "shell plugins module refreshes the installed catalog" "$SHELL_PLUGINS_MODULE" "shell shell rescanPlugins"
assert_file_not_contains "tiling media does not enable a retired popup" "$SHELL_PLUGINS_MODULE" "plugin enable os.media"
assert_true "Lua retirement component syntax valid" "luac -p '$PROJECT_DIR/src/component/application/retirement.lua'"



assert_true "terminal helper Lua syntax valid" "luac -p '$PROJECT_DIR/src/component/terminal/helper.lua'"
assert_true "terminal installer Lua syntax valid" "luac -p '$PROJECT_DIR/src/component/terminal/installer.lua'"
assert_true "herdr menu bash syntax valid" "bash -n '$PROJECT_DIR/data/component/application/herdr/menu'"
assert_true "Herdr Lua component syntax valid" "luac -p '$PROJECT_DIR/src/component/application/keybindings.lua'"

for tool in fzf rg fd bat eza zoxide git lazygit gum ai; do
    assert_file_contains "cliconf covers $tool" "$CLICONF_DATA/en.json" "\"$tool\""
done


USERCONF_LIB="$PROJECT_DIR/scripts/lib/userconf.sh"
assert_file_exists "user config library exists" "$USERCONF_LIB"
assert_file_contains "user config library installs files from a source" "$USERCONF_LIB" "^install_user_file\(\)"
assert_file_contains "user config library installs content from stdin" "$USERCONF_LIB" "^install_user_content\(\)"
assert_file_contains "user config library manages shell blocks" "$USERCONF_LIB" "^install_shell_block\(\)"
assert_true "user config library leaves caller shell options untouched" \
    "bash -c 'set +e +u; source \"$USERCONF_LIB\"; [[ \$- != *e* && \$- != *u* ]]'"
assert_true "no installer keeps the ad hoc timestamped backup" \
    "! grep -qE 'bak-\\\$\\(date' '$PROJECT_DIR'/modules/conf/*/install.sh"

assert_true "app configurations have one canonical root" \
    "[[ -d '$PROJECT_DIR/modules/conf' ]] && ! find '$PROJECT_DIR/modules' -mindepth 1 -maxdepth 1 -type d -name '*conf' ! -name conf -print -quit | grep -q ."

for installer in "$PROJECT_DIR"/modules/conf/*/install.sh; do
    assert_file_contains "$installer sources the user config library" \
        "$installer" "userconf.sh"
done

HERDR_MENU="$PROJECT_DIR/data/component/application/herdr/menu"
assert_file_contains "herdr menu lists the upstream herdr bindings" "$HERDR_MENU" "herdr --default-config"
assert_file_contains "herdr menu supports print mode" "$HERDR_MENU" '[-]-print'
assert_file_contains "herdr menu keeps the upstream display format" "$HERDR_MENU" "→ %s"
assert_file_contains "herdr menu runs only when the herdr process exists" "$HERDR_MENU" "herdr_running"
assert_file_contains "herdr menu checks the herdr server state" "$HERDR_MENU" "herdr status server"
assert_file_contains "herdr menu focuses the herdr window" "$HERDR_MENU" "focuswindow"
assert_file_contains "herdr menu replays keys into herdr" "$HERDR_MENU" "wtype"
assert_file_contains "herdr menu exits cleanly on menu cancel" "$HERDR_MENU" '\|\| exit 0'
assert_file_not_contains "herdr menu has no raw failure suppression" "$HERDR_MENU" '\|\|[[:space:]]*true'
assert_true "Herdr Bash installer was retired" "[[ ! -e '$PROJECT_DIR/modules/conf/herdr/install.sh' ]]"
assert_file_contains "Herdr component publishes the menu" "$PROJECT_DIR/src/component/application/keybindings.lua" "menuDestination"
assert_file_contains "Herdr policy owns the binding" "$PROJECT_DIR/data/component/application/policy.json" '"herdr"'

if ((UID != 0)); then
    USERCONF_SANDBOX="$(mktemp -d)"
    mkdir -p "$USERCONF_SANDBOX/src" "$USERCONF_SANDBOX/dst"
    printf 'first\n' > "$USERCONF_SANDBOX/src/payload"
    printf 'stale\n' > "$USERCONF_SANDBOX/dst/payload"
    (
        set -euo pipefail
        # shellcheck source=../scripts/lib/userconf.sh
        source "$USERCONF_LIB"
        install_user_file "$USERCONF_SANDBOX/src/payload" "$USERCONF_SANDBOX/dst/payload"
    ) 2>/dev/null
    assert_true "user config library installs the new content" \
        "grep -q '^first$' '$USERCONF_SANDBOX/dst/payload'"
    assert_true "user config library keeps the replaced content in a single slot backup" \
        "[[ -f '$USERCONF_SANDBOX/dst/payload.bak' ]] && ! ls '$USERCONF_SANDBOX/dst/' | grep -qE '\.bak-'"
    (
        set -euo pipefail
        # shellcheck source=../scripts/lib/userconf.sh
        source "$USERCONF_LIB"
        install_user_file "$USERCONF_SANDBOX/src/payload" "$USERCONF_SANDBOX/dst/payload"
        install_user_file "$USERCONF_SANDBOX/src/payload" "$USERCONF_SANDBOX/dst/payload"
    ) 2>/dev/null
    assert_true "user config library never accumulates backups across runs" \
        "[[ \$(ls -1 '$USERCONF_SANDBOX/dst/' | grep -c 'payload') -eq 2 ]]"

    printf '# rc\n\n# >>> os sandbox >>>\nold() { :; }\n# <<< os sandbox <<<\n' > "$USERCONF_SANDBOX/rc"
    (
        set -euo pipefail
        # shellcheck source=../scripts/lib/userconf.sh
        source "$USERCONF_LIB"
        install_shell_block "$USERCONF_SANDBOX/rc" "# >>> os sandbox >>>" "# <<< os sandbox <<<" << 'BLOCK'
new() { :; }
BLOCK
    ) 2>/dev/null
    assert_true "shell block replaces the previous marked range" \
        "! grep -q 'old()' '$USERCONF_SANDBOX/rc'"
    assert_true "shell block writes the new body" \
        "grep -q 'new()' '$USERCONF_SANDBOX/rc'"
    assert_true "shell block writes exactly one marked range" \
        "[[ \$(grep -c '>>> os sandbox >>>' '$USERCONF_SANDBOX/rc') -eq 1 ]]"

    printf '# rc\n\n# >>> os sandbox >>>\nnew() { :; }\n# <<< os sandbox <<<\n' > "$USERCONF_SANDBOX/rc-idem"
    (
        set -euo pipefail
        # shellcheck source=../scripts/lib/userconf.sh
        source "$USERCONF_LIB"
        install_shell_block "$USERCONF_SANDBOX/rc-idem" "# >>> os sandbox >>>" "# <<< os sandbox <<<" << 'BLOCK'
new() { :; }
BLOCK
    ) 2>/dev/null
    assert_true "shell block is idempotent" \
        "cmp -s '$USERCONF_SANDBOX/rc' '$USERCONF_SANDBOX/rc-idem'"
    rm -rf "$USERCONF_SANDBOX"
fi

test_summary
