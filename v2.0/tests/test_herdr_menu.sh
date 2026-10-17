#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HERDR_MENU="$PROJECT_DIR/data/component/application/herdr/menu"
HERDR_INSTALLER="$PROJECT_DIR/src/component/application/keybindings.lua"
MSG_DIR="$PROJECT_DIR/data/catalog"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Herdr Click-to-Run Keybindings Menu"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/fakebin" "$SB/home/.config/hypr" "$SB/home/.local/share"

FAKE_ADDR="0xHERDRTEST"

cat > "$SB/default.toml" << 'EOF'
[keys]
# prefix = "ctrl+b"
# help = "prefix+?"
# settings = "prefix+s"
# detach = "prefix+q"
# new_tab = "prefix+c"
# close_pane = "prefix+x"
# split_horizontal = ["prefix+h", "alt+enter"]
# switch_tab = ["prefix+1..9", "alt+1..9"]
# focus_pane_left = "prefix+h"
# workspace_picker = "prefix+w"
# navigate_pane_left = "h"
# navigate_workspace_up = "up"
# unbound_action = ""
# type = "popup" opens a session-modal terminal
# [[keys.command]]
# key = "prefix+alt+g"
EOF

cat > "$SB/user.toml" << 'EOF'
[keys]
prefix = "ctrl+space"
new_tab = "prefix+t"
close_pane = ""
EOF

cat > "$SB/noprefix.toml" << 'EOF'
[keys]
new_tab = "prefix+c"
EOF

cat > "$SB/empty.toml" << 'EOF'
# empty user configuration
EOF

cat > "$SB/fakebin/herdr" << 'EOF'
#!/bin/bash
if [[ "${1:-}" == "--default-config" ]]; then
    if [[ "${HERDR_FAKE_EMPTY:-0}" == "1" ]]; then
        exit 0
    fi
    cat "@SB@/default.toml"
    exit 0
fi
if [[ "${1:-}" == "status" ]]; then
    if [[ "${HERDR_FAKE_RUNNING:-1}" == "1" ]]; then
        printf '{"status":"running","running":true}'
    else
        printf '{"status":"stopped","running":false}'
    fi
    exit 0
fi
exit 0
EOF

cat > "$SB/fakebin/hyprctl" << 'EOF'
#!/bin/bash
printf 'HYPRCTL: %s\n' "$*" >> "@SB@/hyprctl.log"
if [[ "${1:-}" == "clients" ]]; then
    cat "@SB@/clients.json"
    exit 0
fi
if [[ "${1:-}" == "monitors" ]]; then
    printf '[{"focused":true,"height":1080}]'
    exit 0
fi
exit 0
EOF

cat > "$SB/fakebin/jq" << 'EOF'
#!/bin/bash
filter="${*: -1}"
if [[ "$filter" == *"height"* ]]; then
    printf '1080'
    exit 0
fi
if [[ "$filter" == *".pid"* ]]; then
    printf '%s %s\n' "@SB_ADDR@" "${HERDR_FAKE_CPID:-424242}"
    exit 0
fi
if [[ "$filter" == *"address"* ]]; then
    if [[ "${HERDR_FAKE_NAME_MATCH:-1}" == "1" ]]; then
        printf '%s\n' "@SB_ADDR@"
    fi
    exit 0
fi
exit 0
EOF

cat > "$SB/fakebin/wtype" << 'EOF'
#!/bin/bash
printf '<%s>' "$@" >> "@SB@/wtype.log"
printf '\n' >> "@SB@/wtype.log"
exit 0
EOF

cat > "$SB/fakebin/omarchy-menu-select" << 'EOF'
#!/bin/bash
if [[ "${HERDR_FAKE_SELECT_MODE:-}" == "cancel" ]]; then
    exit 1
fi
printf '%s\n' "${HERDR_FAKE_SELECTION:-}"
exit 0
EOF

cat > "$SB/fakebin/pgrep" << 'EOF'
#!/bin/bash
if [[ "${1:-}" == "-x" && "${2:-}" == "herdr" ]]; then
    if [[ -n "${HERDR_FAKE_PIDS:-}" ]]; then
        # shellcheck disable=SC2086
        printf '%s\n' $HERDR_FAKE_PIDS
        exit 0
    fi
    exit 1
fi
exit 1
EOF

chmod +x "$SB"/fakebin/*
sed -i "s|@SB@|$SB|g" "$SB"/fakebin/*
sed -i "s|@SB_ADDR@|$FAKE_ADDR|g" "$SB"/fakebin/jq

printf '[{"address":"%s","pid":424242,"class":"kitty","title":"host: work","initialClass":"","initialTitle":"herdr"}]' "$FAKE_ADDR" > "$SB/clients.json"

menu_lib() (
    grep -qF 'if [[ "$print_only" == "true" ]]; then' "$HERDR_MENU" || return 1
    sed -n '1,/^if \[\[ "\${BASH_SOURCE\[0\]:-}" == "\$0" \]\]; then$/p' "$HERDR_MENU" | head -n -1 > "$SB/menu-lib.sh"
    bash -n "$SB/menu-lib.sh"
)

fake_env() {
    export PATH="$SB/fakebin:$PATH"
    export HERDR_CONFIG_PATH="$SB/user.toml"
    export HERDR_FAKE_RUNNING=1 HERDR_FAKE_NAME_MATCH=1 HERDR_FAKE_EMPTY=0
    export HERDR_FAKE_SELECT_MODE="" HERDR_FAKE_SELECTION=""
}

gen_records() (
    fake_env
    # shellcheck source=/dev/null
    source "$SB/menu-lib.sh"
    set +e
    output_records > "$SB/records.txt" 2>/dev/null
)

test_section "Menu Structure & Conventions"

assert_file_exists "herdr menu script exists" "$HERDR_MENU"
assert_file_exists "Herdr keybinding component exists" "$HERDR_INSTALLER"
assert_true "Herdr Bash installer was removed" "[[ ! -e '$PROJECT_DIR/modules/conf/herdr/install.sh' ]]"
assert_true "Herdr policy is registered" "[[ \$(jq -r '.herdr.kind' '$PROJECT_DIR/data/component/application/policy.json') == keybindings ]]"
assert_file_contains "herdr menu uses strict mode" "$HERDR_MENU" "set -euo pipefail"
assert_true "herdr menu has no raw failure suppression" \
    "! grep -qE '\\|\\|[[:space:]]*true\\b' '$HERDR_MENU'"
assert_file_contains "Herdr component preserves unrelated binding text" "$HERDR_INSTALLER" "Blocks.merge"
assert_file_contains "Herdr component warns when bindings are missing" "$HERDR_INSTALLER" "herdr.bind_skipped"

test_section "Records: Display Parity & Raw Channel"

assert_true "menu library extracts cleanly" "menu_lib"
assert_true "sandbox records generated" "gen_records && [[ -s '$SB/records.txt' ]]"
assert_true "every record carries display and raw columns" \
    "awk -F'\t' 'NF!=2{bad=1} END{exit bad?1:0}' '$SB/records.txt'"
assert_true "prefix row comes first" \
    "head -n 1 '$SB/records.txt' | grep -q '^PREFIX'"
assert_true "display column keeps the upstream width format" \
    "grep -qE '^.{32} → ' '$SB/records.txt'"
assert_true "user prefix override wins" \
    "grep -q '^PREFIX.*CTRL [+] SPACE' '$SB/records.txt'"
assert_true "user action override wins" \
    "grep -q 'PREFIX [+] T.*New tab' '$SB/records.txt'"
assert_true "unbound user action disappears" \
    "! grep -q 'Close pane' '$SB/records.txt'"
assert_true "prose lines never parse as bindings" \
    "! grep -qi 'popup opens' '$SB/records.txt'"
assert_true "custom commands never leak into the menu" \
    "! grep -q 'prefix+alt+g' '$SB/records.txt'"
assert_true "navigate rows keep their mode prefix" \
    "grep -q '^NAVIGATE [+] H.*Pane left' '$SB/records.txt'"
assert_true "array binding replays its first alternative" \
    "grep 'Split horizontal' '$SB/records.txt' | grep -q 'prefix+h$'"
assert_true "raw bindings are lowercase" \
    "! awk -F'\t' '{print \$2}' '$SB/records.txt' | grep -q '[A-Z]'"
assert_true "print mode shows display only" \
    "PATH='$SB/fakebin:$PATH' HERDR_CONFIG_PATH='$SB/user.toml' bash '$HERDR_MENU' --print 2>/dev/null | grep -q '^PREFIX' && ! PATH='$SB/fakebin:$PATH' HERDR_CONFIG_PATH='$SB/user.toml' bash '$HERDR_MENU' --print 2>/dev/null | grep -qP '\t'"

test_section "Prefix Resolution"

assert_true "user config prefix wins" \
    "PATH='$SB/fakebin:$PATH' HERDR_CONFIG_PATH='$SB/user.toml' bash -c 'source \"$SB/menu-lib.sh\" >/dev/null 2>&1; [[ \"\$(resolve_herdr_prefix)\" == ctrl+space ]]'"
assert_true "default prefix applies without user override" \
    "PATH='$SB/fakebin:$PATH' HERDR_CONFIG_PATH='$SB/noprefix.toml' bash -c 'source \"$SB/menu-lib.sh\" >/dev/null 2>&1; [[ \"\$(resolve_herdr_prefix)\" == ctrl+b ]]'"
assert_true "empty default falls back to ctrl+b" \
    "PATH='$SB/fakebin:$PATH' HERDR_CONFIG_PATH='$SB/noprefix.toml' HERDR_FAKE_EMPTY=1 bash -c 'source \"$SB/menu-lib.sh\" >/dev/null 2>&1; [[ \"\$(resolve_herdr_prefix)\" == ctrl+b ]]'"

test_section "Key Replay Mapping"

replay_log() (
    fake_env
    # shellcheck source=/dev/null
    source "$SB/menu-lib.sh"
    set +e
    rm -f "$SB/wtype.log"
    replay_herdr_keys "$1" >/dev/null 2>&1
)

assert_true "prefix action replays prefix chord then key" \
    "replay_log 'prefix+c' && grep -q '<-M><ctrl><-k><space><-m><ctrl>' '$SB/wtype.log' && grep -q '<-k><c>' '$SB/wtype.log'"
assert_true "prefix chord holds shift for capitals" \
    "replay_log 'prefix+shift+n' && grep -q '<-M><shift><-k><n><-m><shift>' '$SB/wtype.log'"
assert_true "direct chord replays modifiers together" \
    "replay_log 'ctrl+alt+left' && grep -q '<-M><ctrl><-M><alt><-k><Left><-m><alt><-m><ctrl>' '$SB/wtype.log'"
assert_true "enter maps to the xkb return key" \
    "replay_log 'alt+enter' && grep -q '<-M><alt><-k><Return><-m><alt>' '$SB/wtype.log'"
assert_true "navigate mode replays the bare key" \
    "replay_log 'navigate+h' && grep -q '<-k><h>' '$SB/wtype.log' && [[ \$(wc -l < '$SB/wtype.log') -eq 1 ]]"
assert_true "indexed ranges replay nothing" \
    "replay_log 'prefix+1..9' && [[ ! -s '$SB/wtype.log' ]]"
assert_true "bare prefix replays the resolved chord" \
    "replay_log 'prefix' && grep -q '<-M><ctrl><-k><space><-m><ctrl>' '$SB/wtype.log'"
assert_true "punctuation maps to xkb names" \
    "replay_log 'prefix+?' && grep -q '<-k><?>' '$SB/wtype.log'"

test_section "Process Gating & End-to-End"

integration_run() (
    fake_env
    rm -f "$SB/hyprctl.log" "$SB/wtype.log"
    export HERDR_FAKE_RUNNING=1 HERDR_FAKE_NAME_MATCH=1 HERDR_FAKE_EMPTY=0 HERDR_FAKE_PIDS="" HERDR_FAKE_CPID="424242"
    export HERDR_FAKE_SELECT_MODE="" HERDR_FAKE_SELECTION=""
    case "${1:-}" in
        cancel)
            HERDR_FAKE_SELECT_MODE="cancel"
            ;;
        down)
            HERDR_FAKE_RUNNING=0
            HERDR_FAKE_PIDS=""
            HERDR_FAKE_SELECTION="$(bash "$HERDR_MENU" --print 2>/dev/null | head -n 1)"
            [[ -n "$HERDR_FAKE_SELECTION" ]] || return 1
            ;;
        named)
            HERDR_FAKE_SELECTION="$(bash "$HERDR_MENU" --print 2>/dev/null | grep -F 'New tab')"
            [[ -n "$HERDR_FAKE_SELECTION" ]] || return 1
            ;;
        pids)
            HERDR_FAKE_NAME_MATCH=0
            HERDR_FAKE_CPID="$$"
            HERDR_FAKE_PIDS="$$"
            printf '[{"address":"%s","pid":%s,"class":"kitty","title":"shell","initialClass":"","initialTitle":""}]' "$FAKE_ADDR" "$$" > "$SB/clients.json"
            HERDR_FAKE_SELECTION="$(bash "$HERDR_MENU" --print 2>/dev/null | grep -F 'Workspace picker')"
            [[ -n "$HERDR_FAKE_SELECTION" ]] || return 1
            ;;
        empty)
            HERDR_FAKE_EMPTY=1
            HERDR_CONFIG_PATH="$SB/empty.toml"
            ;;
    esac
    export HERDR_FAKE_RUNNING HERDR_FAKE_NAME_MATCH HERDR_FAKE_EMPTY HERDR_FAKE_PIDS HERDR_FAKE_CPID HERDR_FAKE_SELECT_MODE HERDR_FAKE_SELECTION
    bash "$HERDR_MENU" >/dev/null 2>&1
    rc=$?
    printf '[{"address":"%s","pid":424242,"class":"kitty","title":"host: work","initialClass":"","initialTitle":"herdr"}]' "$FAKE_ADDR" > "$SB/clients.json"
    return "$rc"
)

assert_true "cancelled menu exits cleanly without side effects" \
    "integration_run cancel && ! grep -q 'focus' '$SB/hyprctl.log' 2>/dev/null && [[ ! -s '$SB/wtype.log' ]]"
assert_true "server down performs no dispatch" \
    "integration_run down && ! grep -q 'focus' '$SB/hyprctl.log' 2>/dev/null && [[ ! -s '$SB/wtype.log' ]]"
assert_true "named herdr window is focused and fed" \
    "integration_run named && grep -q '$FAKE_ADDR' '$SB/hyprctl.log' && grep -q '<-k><t>' '$SB/wtype.log'"
assert_true "pid fallback finds the hosting terminal" \
    "integration_run pids && grep -q '$FAKE_ADDR' '$SB/hyprctl.log' && grep -q '<-k><w>' '$SB/wtype.log'"
assert_true "empty listing exits silently" \
    "integration_run empty && [[ ! -s '$SB/hyprctl.log' ]]"
assert_true "print mode needs no running server" \
    "HERDR_FAKE_RUNNING=0 HERDR_FAKE_PIDS='' PATH='$SB/fakebin:$PATH' HERDR_CONFIG_PATH='$SB/user.toml' bash '$HERDR_MENU' --print 2>/dev/null | grep -q '^PREFIX'"

test_section "Installer Behaviour in Sandbox"

sandbox_install() (
    export HOME="$SB/home" XDG_CONFIG_HOME="$SB/home/.config" XDG_DATA_HOME="$SB/home/.local/share"
    export OS_LANG="${1:-en}"
    if [[ "${3:-reset}" != "keep" ]]; then
        rm -rf "${SB:?}/home"
        mkdir -p "$SB/home/.config/hypr" "$SB/home/.local/share"
        if [[ "${2:-1}" == "1" ]]; then
            printf 'o.bind("SUPER + RETURN", "Terminal", "xdg-terminal-exec")\n' > "$SB/home/.config/hypr/bindings.lua"
        fi
    fi
    lua -E "$PROJECT_DIR/src/main.lua" "$PROJECT_DIR" apply-settings herdr > "$SB/install.out" 2> "$SB/install.err"
    printf '%s' "$?"
)

assert_true "sandbox install succeeds" \
    "[[ \"\$(sandbox_install en 1)\" == 0 ]]"
assert_true "menu lands user scoped with 755" \
    "[[ -x '$SB/home/.local/share/omarchy/herdr-keybindings-menu' ]] && [[ \"\$(stat -c %a '$SB/home/.local/share/omarchy/herdr-keybindings-menu')\" == 755 ]]"
assert_true "existing bindings survive the managed block" \
    "grep -q 'SUPER + RETURN' '$SB/home/.config/hypr/bindings.lua' && grep -q 'os-herdr-keys (managed)' '$SB/home/.config/hypr/bindings.lua'"
assert_true "managed block unbinds then rebinds super-ctrl-k" \
    "grep -q 'hl.unbind(\"SUPER + CTRL + K\")' '$SB/home/.config/hypr/bindings.lua' && grep -q 'o.bind(\"SUPER + CTRL + K\", \"Herdr keybindings\"' '$SB/home/.config/hypr/bindings.lua'"
assert_true "repeated installs converge byte for byte" \
    "cp '$SB/home/.config/hypr/bindings.lua' '$SB/once.lua' && sandbox_install en 1 keep >/dev/null && sandbox_install en 1 keep >/dev/null && cmp -s '$SB/once.lua' '$SB/home/.config/hypr/bindings.lua'"
assert_true "exactly one managed block survives" \
    "[[ \$(grep -c '^-- os-herdr-keys (managed)$' '$SB/home/.config/hypr/bindings.lua') -eq 1 ]]"
assert_true "missing bindings file warns but succeeds" \
    "[[ \"\$(sandbox_install en 0)\" == 0 ]] && grep -q 'Hyprland Herdr binding skipped' '$SB/install.err'"
assert_true "english completion message is exact" \
    "sandbox_install en 1 >/dev/null && grep -qx 'Desktop integration installed: Herdr' '$SB/install.out'"
assert_true "italian completion message is exact" \
    "sandbox_install it 1 >/dev/null && grep -qx 'Integrazione desktop installata: Herdr' '$SB/install.out'"
assert_true "replaced menu keeps a single slot backup" \
    "sandbox_install en 1 >/dev/null && printf 'stale' > '$SB/home/.local/share/omarchy/herdr-keybindings-menu' && sandbox_install en 1 keep >/dev/null && [[ -f '$SB/home/.local/share/omarchy/herdr-keybindings-menu.bak' ]] && [[ \$(ls '$SB/home/.local/share/omarchy' | grep -c 'herdr-keybindings-menu') -eq 2 ]]"

test_section "Wiring, Provisioning & Catalogues"

assert_file_contains "make herdr uses the setup pipeline" "$PROJECT_DIR/Makefile" 'herdr:'
assert_true "make herdr selects its dedicated scope" \
    "grep -A1 '^herdr:' '$PROJECT_DIR/Makefile' | grep -q 'setup SCOPE=herdr'"
assert_file_contains "setup accepts the dedicated Herdr scope" "$PROJECT_DIR/scripts/setup.sh" 'herdr|performance'
assert_file_contains "setup applies Herdr through Lua" "$PROJECT_DIR/scripts/setup.sh" 'apply-settings herdr'
assert_file_contains "make phony lists herdr" "$PROJECT_DIR/Makefile" 'herdr'
assert_file_contains "make lint covers every app config" "$PROJECT_DIR/Makefile" 'modules/conf/\*/\*.sh'
assert_file_contains "make help lists herdr" "$PROJECT_DIR/data/component/project/policy.json" 'make.herdr'
assert_file_contains "setup discovers app installers per user" "$PROJECT_DIR/scripts/lib/modules/24-user-configurations.sh" 'modules/conf/\*/install.sh'
assert_file_contains "ci syntax job covers app installers" "$PROJECT_DIR/../.github/workflows/ci.yml" 'modules/conf/'
assert_file_contains "test runner includes the herdr suite" "$PROJECT_DIR/data/component/testing/policy.json" "test_herdr_menu.sh"

for lang in en it fr de es pt; do
    assert_true "catalogue $lang carries the herdr keys" \
        "for k in make.herdr herdr.bind_skipped gui.install_done; do grep -q \"^\$k=\" '$MSG_DIR/$lang.msg' || exit 1; done"
done

assert_true "herdr keys keep placeholder parity" \
    "for k in make.herdr herdr.bind_skipped gui.install_done; do n=\$(awk -F%s -v k=\"^\$k=\" '\$0 ~ k { print NF - 1 }' \"\$MSG_DIR/en.msg\"); for l in it fr de es pt; do m=\$(awk -F%s -v k=\"^\$k=\" '\$0 ~ k { print NF - 1 }' \"\$MSG_DIR/\$l.msg\"); [[ \"\$n\" == \"\$m\" ]] || exit 1; done; done"

if [[ -x /usr/bin/omarchy-menu-herdr-keybindings || -x /usr/share/omarchy/bin/omarchy-menu-herdr-keybindings ]] && command -v herdr &>/dev/null; then
    UPSTREAM="$(command -v omarchy-menu-herdr-keybindings)"
    assert_true "display column matches upstream os" \
        "diff -q <(bash '$HERDR_MENU' --print 2>/dev/null) <(bash '$UPSTREAM' --print 2>/dev/null) >/dev/null"
else
    assert_warn "upstream parity skipped outside os" "false"
fi

test_summary
