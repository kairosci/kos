#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SHELL_PLUGINS_MODULE="$PROJECT_DIR/scripts/lib/modules/35-shell-plugins.sh"
CLICONF_DATA="$PROJECT_DIR/conf/cli/data"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Config Validity & Placement Regression"

assert_file_contains "shell plugins module keeps omamp on the right" "$SHELL_PLUGINS_MODULE" "section right"



assert_true "cliconf helpers bash syntax valid" "bash -n '$CLICONF_DATA/helpers.sh'"
assert_true "cliconf installer bash syntax valid" "bash -n '$PROJECT_DIR/conf/cli/install.sh'"
assert_true "herdr menu bash syntax valid" "bash -n '$PROJECT_DIR/conf/herdr/data/herdr-keybindings-menu'"
assert_true "herdr installer bash syntax valid" "bash -n '$PROJECT_DIR/conf/herdr/install.sh'"

for tool in fzf rg fd bat eza zoxide git lazygit gum ai; do
    assert_file_contains "cliconf covers $tool" "$CLICONF_DATA/helpers.sh" "$tool)"
done


USERCONF_LIB="$PROJECT_DIR/scripts/lib/userconf.sh"
assert_file_exists "user config library exists" "$USERCONF_LIB"
assert_file_contains "user config library installs files from a source" "$USERCONF_LIB" "^install_user_file\(\)"
assert_file_contains "user config library installs content from stdin" "$USERCONF_LIB" "^install_user_content\(\)"
assert_file_contains "user config library manages shell blocks" "$USERCONF_LIB" "^install_shell_block\(\)"
assert_true "user config library leaves caller shell options untouched" \
    "bash -c 'set +e +u; source \"$USERCONF_LIB\"; [[ \$- != *e* && \$- != *u* ]]'"
assert_true "no installer keeps the ad hoc timestamped backup" \
    "! grep -qE 'bak-\\\$\\(date' '$PROJECT_DIR'/conf/*/install.sh"

assert_true "app configurations have one canonical root" \
    "[[ -d '$PROJECT_DIR/conf' ]] && ! find '$PROJECT_DIR' -mindepth 1 -maxdepth 1 -type d -name '*conf' ! -name conf -print -quit | grep -q ."

for installer in "$PROJECT_DIR"/conf/*/install.sh; do
    assert_file_contains "$installer sources the user config library" \
        "$installer" "userconf.sh"
done

HERDR_MENU="$PROJECT_DIR/conf/herdr/data/herdr-keybindings-menu"
assert_file_contains "herdr menu lists the upstream herdr bindings" "$HERDR_MENU" "herdr --default-config"
assert_file_contains "herdr menu supports print mode" "$HERDR_MENU" '[-]-print'
assert_file_contains "herdr menu keeps the upstream display format" "$HERDR_MENU" "→ %s"
assert_file_contains "herdr menu runs only when the herdr process exists" "$HERDR_MENU" "herdr_running"
assert_file_contains "herdr menu checks the herdr server state" "$HERDR_MENU" "herdr status server"
assert_file_contains "herdr menu focuses the herdr window" "$HERDR_MENU" "focuswindow"
assert_file_contains "herdr menu replays keys into herdr" "$HERDR_MENU" "wtype"
assert_file_contains "herdr menu exits cleanly on menu cancel" "$HERDR_MENU" '\|\| exit 0'
assert_file_not_contains "herdr menu has no raw failure suppression" "$HERDR_MENU" '\|\|[[:space:]]*true'
assert_file_contains "herdr installer deploys the menu per user" "$PROJECT_DIR/conf/herdr/install.sh" "herdr-keybindings-menu"
assert_file_contains "herdr installer manages the hyprland binding" "$PROJECT_DIR/conf/herdr/install.sh" "bindings.lua"
assert_file_contains "herdr installer keeps super-ctrl-k on herdr" "$PROJECT_DIR/conf/herdr/install.sh" 'SUPER [+] CTRL [+] K'

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

    printf '# rc\n\n# >>> omaconf sandbox >>>\nold() { :; }\n# <<< omaconf sandbox <<<\n' > "$USERCONF_SANDBOX/rc"
    (
        set -euo pipefail
        # shellcheck source=../scripts/lib/userconf.sh
        source "$USERCONF_LIB"
        install_shell_block "$USERCONF_SANDBOX/rc" "# >>> omaconf sandbox >>>" "# <<< omaconf sandbox <<<" << 'BLOCK'
new() { :; }
BLOCK
    ) 2>/dev/null
    assert_true "shell block replaces the previous marked range" \
        "! grep -q 'old()' '$USERCONF_SANDBOX/rc'"
    assert_true "shell block writes the new body" \
        "grep -q 'new()' '$USERCONF_SANDBOX/rc'"
    assert_true "shell block writes exactly one marked range" \
        "[[ \$(grep -c '>>> omaconf sandbox >>>' '$USERCONF_SANDBOX/rc') -eq 1 ]]"

    printf '# rc\n\n# >>> omaconf sandbox >>>\nnew() { :; }\n# <<< omaconf sandbox <<<\n' > "$USERCONF_SANDBOX/rc-idem"
    (
        set -euo pipefail
        # shellcheck source=../scripts/lib/userconf.sh
        source "$USERCONF_LIB"
        install_shell_block "$USERCONF_SANDBOX/rc-idem" "# >>> omaconf sandbox >>>" "# <<< omaconf sandbox <<<" << 'BLOCK'
new() { :; }
BLOCK
    ) 2>/dev/null
    assert_true "shell block is idempotent" \
        "cmp -s '$USERCONF_SANDBOX/rc' '$USERCONF_SANDBOX/rc-idem'"
    rm -rf "$USERCONF_SANDBOX"
fi

test_summary
