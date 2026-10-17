#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
WORK_DIR=$(mktemp -d)
trap 'rm -rf -- "$WORK_DIR"' EXIT
CLEAN="$PROJECT_DIR/modules/conf/session/scripts/clean-hypr.sh"
cat > "$WORK_DIR/input.lua" <<'LUA'
-- Introductory comment
local text = "keep -- inside a string"
local block = [=[line one


line four -- literal
]=]
--[==[ discard this long comment ]==]
--[==[
-- os example (managed)
local retained = true
-- end os example (managed)
]==]
local retained = true
assert(retained)
assert(text == "keep -- inside a string")
assert(block == "line one\n\n\nline four -- literal\n")
local literal = [=[-- os fixture (managed)
preserve literal data
-- end os fixture (managed)]=]
assert(literal:find("preserve literal data", 1, true))
-- os locale (managed)
local layout = "it"
-- end os locale (managed)
assert(layout == "it")
LUA
assert_true "Lua cleaner parses comments without changing string contents" "bash '$CLEAN' '$WORK_DIR/input.lua' '$WORK_DIR/state.lua' '$WORK_DIR/state-new.lua' > '$WORK_DIR/clean.lua' && lua '$WORK_DIR/clean.lua'"
assert_true "Lua cleaner removes narrative and block comments" "! grep -q 'Introductory\|discard this' '$WORK_DIR/clean.lua'"
assert_true "Lua cleanup is idempotent" "bash '$CLEAN' '$WORK_DIR/clean.lua' '$WORK_DIR/state-new.lua' '$WORK_DIR/state-again.lua' > '$WORK_DIR/again.lua' && cmp '$WORK_DIR/clean.lua' '$WORK_DIR/again.lua' && cmp '$WORK_DIR/state-new.lua' '$WORK_DIR/state-again.lua'"
cat "$WORK_DIR/clean.lua" > "$WORK_DIR/updated.lua"
cat >> "$WORK_DIR/updated.lua" <<'LUA'
-- os locale (managed)
local layout = "fr"
-- end os locale (managed)
LUA
assert_true "managed policy updates replace the previous commentless body" "bash '$CLEAN' '$WORK_DIR/updated.lua' '$WORK_DIR/state-new.lua' '$WORK_DIR/state-updated.lua' > '$WORK_DIR/updated-clean.lua' && [[ \$(grep -c 'local layout' '$WORK_DIR/updated-clean.lua') == 1 ]] && grep -q 'local layout = \"fr\"' '$WORK_DIR/updated-clean.lua'"
cat >> "$WORK_DIR/updated.lua" <<'LUA'
-- os locale (managed)
local layout = "de"
-- end os locale (managed)
LUA
assert_true "repeated managed blocks keep only the latest policy" "bash '$CLEAN' '$WORK_DIR/updated.lua' '$WORK_DIR/state-new.lua' > '$WORK_DIR/duplicate-clean.lua' && [[ \$(grep -c 'local layout' '$WORK_DIR/duplicate-clean.lua') == 1 ]] && grep -q 'local layout = \"de\"' '$WORK_DIR/duplicate-clean.lua'"
printf 'local invalid =\n' > "$WORK_DIR/invalid.lua"
assert_true "invalid Lua is rejected" "! bash '$CLEAN' '$WORK_DIR/invalid.lua'"
printf 'require("unknown.omarchy.module")\n' > "$WORK_DIR/unknown.lua"
assert_true "unknown runtime references fail instead of being removed" "! bash '$CLEAN' '$WORK_DIR/unknown.lua'"
cat > "$WORK_DIR/native.lua" <<'LUA'
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")
require("default.hypr.omarchy")
require("default.hypr.toggles")
local omarchy_gdk_scale = 2
local command = "omarchy-cmd-terminal-cwd"
LUA
assert_true "native bootstrap becomes an OS adapter without changing monitor scale" "bash '$CLEAN' '$WORK_DIR/native.lua' > '$WORK_DIR/native-clean.lua' && ! grep -qi omarchy '$WORK_DIR/native-clean.lua' && grep -q 'desktop.defaults()' '$WORK_DIR/native-clean.lua' && grep -q 'local gdk_scale = 2' '$WORK_DIR/native-clean.lua' && grep -q 'os cmd terminal cwd' '$WORK_DIR/native-clean.lua'"
printf '%s\n' '{"idle":{"lock":300},"bar":{"position":"bottom","layout":{"left":["omarchy.menu","omarchy.workspaces"],"center":[{"id":"omarchy.clock","format":"HH:mm"}],"right":["personal.widget"]}},"plugins":["personal.plugin"]}' > "$WORK_DIR/shell.json"
session_layout() {
    jq --slurpfile policy "$PROJECT_DIR/modules/conf/session/data/policy.json" \
        --slurpfile defaults "$PROJECT_DIR/modules/conf/session/data/shell.json" \
        -f "$PROJECT_DIR/modules/conf/session/scripts/shell.jq" "$1"
}
assert_true "panel migration preserves the idle policy and calendar preferences" "session_layout '$WORK_DIR/shell.json' > '$WORK_DIR/shell-new.json' && jq -e '.idle.lock == 300 and ([.bar.layout[][]] | length == 0) and (.plugins | any(. == \"personal.plugin\")) and (.plugins | any(type == \"object\" and .id == \"os.menu\"))' '$WORK_DIR/shell-new.json'"
assert_true "panel migration is idempotent" "session_layout '$WORK_DIR/shell-new.json' > '$WORK_DIR/shell-again.json' && cmp '$WORK_DIR/shell-new.json' '$WORK_DIR/shell-again.json'"
printf '%s\n' '{"learn":{},"learn.arch":{},"bar":{},"style.bar.position":{},"apps":{"provider":"apps"},"personal":{},"setup":{},"setup.config":{},"update.config":{}}' > "$WORK_DIR/menu.json"
assert_true "menu filtering removes Learn and bar routes while retaining Apps and personal entries" "jq --slurpfile policy '$PROJECT_DIR/modules/conf/session/data/policy.json' -f '$PROJECT_DIR/modules/conf/session/scripts/filter-menu.jq' '$WORK_DIR/menu.json' | jq -e 'keys == [\"apps\",\"personal\"]'"
printf '%s\n' '{"literal":",}","url":"https://example.org",/* block */"items":[1,2,],}' > "$WORK_DIR/jsonc.json"
assert_true "JSONC parsing preserves strings while stripping comments and trailing commas" "lua '$PROJECT_DIR/modules/conf/session/scripts/jsonc.lua' '$WORK_DIR/jsonc.json' | jq -e '.literal == \",}\" and .url == \"https://example.org\" and .items == [1,2]'"
assert_true "managed state is JSON data rather than executable Lua" "jq -e 'type == \"object\" and has(\"os locale\")' '$WORK_DIR/state-new.lua'"
mkdir -p "$WORK_DIR/homes/tester/.config/"{hypr,os/plugins/os.menu,os/extensions} "$WORK_DIR/trusted"
for file in Menu.qml MenuModel.js manifest.json; do
    printf 'fixture\n' > "$WORK_DIR/homes/tester/.config/os/plugins/os.menu/$file"
done
while IFS= read -r id; do
    mkdir -p "$WORK_DIR/homes/tester/.config/os/plugins/$id"
    touch "$WORK_DIR/homes/tester/.config/os/plugins/$id/fixture"
done < <(jq -r '.menu.id,.panels[].id,(.clockWidget | select(.enabled) | .id)' "$PROJECT_DIR/modules/conf/session/data/policy.json")
mkdir -p "$WORK_DIR/homes/tester/.local/share/os/session/data"
printf '{}\n' > "$WORK_DIR/homes/tester/.local/share/os/session/data/policy.json"
printf '{}\n' > "$WORK_DIR/homes/tester/.config/os/extensions/os-menu.json"
printf '{}\n' > "$WORK_DIR/homes/tester/.config/os/shell.json"
touch "$WORK_DIR/homes/tester/.config/hypr/hyprland.lua"
sed -e "s|/usr/local/lib/os|$WORK_DIR/trusted|g" -e "s|/home/\*|$WORK_DIR/homes/*|g" \
    "$PROJECT_DIR/scripts/lib/modules/97-session.sh" > "$WORK_DIR/stage.sh"
cat > "$WORK_DIR/harness.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$1"
SETUP_SCOPE=session
PRIMARY_USER=tester
user_as() {
    shift
    case "$1" in
        env)
            if [[ "$*" == *'qs ipc call shell ping' ]]; then
                printf 'ok\n'
            elif [[ "${SESSION_TEST_CHANGE:-0}" == 1 ]]; then
                printf 'changed\n' >> "$SESSION_TEST_ROOT/homes/tester/.config/os/plugins/os.menu/Menu.qml"
            fi
            ;;
        hyprctl)
            if [[ "$2" == configerrors && "${SESSION_TEST_ERRORS:-0}" == 1 ]]; then
                printf 'invalid configuration\n'
            elif [[ "$2" == layers ]]; then
                if [[ $(awk '$4 == "summon" || $4 == "hide" { action=$4 } END { print action }' "$SESSION_TEST_ROOT/commands.log") == summon ]]; then
                    printf '{"monitor":{"levels":{"2":[{"namespace":"os-control"}]}}}\n'
                else
                    printf '{"monitor":{"levels":{"0":[{"namespace":"os-clock"}]}}}\n'
                fi
            fi
            ;;
        qs) printf 'ok\n' ;;
        systemctl) return 0 ;;
        bash) cat > /dev/null ;;
        *) return 1 ;;
    esac
}
omarchy_as() {
    printf '%s\n' "$*" >> "$SESSION_TEST_ROOT/commands.log"
    shift
    if [[ "$*" == 'shell shell call os.menu status {}' ]]; then
        local route
        route=$(awk '$2 == "menu" && $3 == "summon" { route=$4 } END { print route }' "$SESSION_TEST_ROOT/commands.log")
        if [[ "${SESSION_TEST_APPS_EMPTY:-0}" == 1 ]]; then
            printf '{"policyLoaded":true,"availableApps":0,"modelApps":0,"menus":["apps"]}\n'
        else
            printf '{"policyLoaded":true,"availableApps":10,"modelApps":10,"renderedWidth":400,"route":"%s","menus":["apps"]}\n' "$route"
        fi
    elif [[ "$1 $2 ${3:-}" == 'shell shell call' ]]; then
        local opened=false
        if [[ $(awk -v id="$4" '($4 == "summon" || $4 == "hide") && $5 == id { action=$4 } END { print action }' "$SESSION_TEST_ROOT/commands.log") == summon ]]; then opened=true; fi
        printf '{"ready":true,"opened":%s,"id":"%s"}\n' "$opened" "$4"
    else
        printf 'ok\n'
    fi
}
err() { printf '%s\n' "$*" >&2; exit 1; }
source "$SESSION_TEST_ROOT/stage.sh"
SH
export SESSION_TEST_ROOT="$WORK_DIR"
assert_true "unchanged configuration checks the menu without restarting the shell" "bash '$WORK_DIR/harness.sh' '$PROJECT_DIR' && ! grep -q 'restart shell' '$WORK_DIR/commands.log'"
: > "$WORK_DIR/commands.log"
assert_true "changed menu configuration restarts the shell after validation" "SESSION_TEST_CHANGE=1 bash '$WORK_DIR/harness.sh' '$PROJECT_DIR' && grep -q 'restart shell' '$WORK_DIR/commands.log'"
: > "$WORK_DIR/commands.log"
assert_true "compositor errors prevent a shell restart" "! SESSION_TEST_CHANGE=1 SESSION_TEST_ERRORS=1 bash '$WORK_DIR/harness.sh' '$PROJECT_DIR' && ! grep -q 'restart shell' '$WORK_DIR/commands.log'"
assert_true "controls and panels are retired from the session policy" "jq -e 'has(\"controls\") | not' '$PROJECT_DIR/modules/conf/session/data/policy.json' && jq -e '.panels == []' '$PROJECT_DIR/modules/conf/session/data/policy.json'"
assert_true "session menu branding carries no panel shortcuts" "jq -e 'length == 2 and all(.[]; .command | startswith(\"os menu toggle\"))' '$PROJECT_DIR/modules/conf/session/data/bindings.json'"
assert_true "managed menu data is retired" "[[ ! -e '$PROJECT_DIR/modules/conf/session/data/menu.json' ]]"
assert_true "installer retires previously installed control copies" "grep -q 'os.controls' '$PROJECT_DIR/modules/conf/session/install.sh'"
printf '%s\n' '{"plugins":[{"id":"os.audio"},{"id":"personal.plugin"}],"bar":{"layout":[]}}' > "$WORK_DIR/stale-shell.json"
assert_true "retired os panels are dropped from the migrated shell" "jq --slurpfile policy '$PROJECT_DIR/modules/conf/session/data/policy.json' --slurpfile defaults '$PROJECT_DIR/modules/conf/session/data/shell.json' -f '$PROJECT_DIR/modules/conf/session/scripts/shell.jq' '$WORK_DIR/stale-shell.json' | jq -e '[.plugins[] | if type == \"string\" then . else .id end] | index(\"os.audio\") == null'"
assert_true "an empty Apps catalogue fails runtime verification" "! SESSION_TEST_APPS_EMPTY=1 bash '$WORK_DIR/harness.sh' '$PROJECT_DIR'"
source "$PROJECT_DIR/modules/conf/session/scripts/clock.sh"
declare -A test_clock=()
jq '.clockWidget.enabled = true' "$PROJECT_DIR/modules/conf/session/data/policy.json" > "$WORK_DIR/enabled-policy.json"
ClockWidget::new test_clock "$PROJECT_DIR/modules/conf/session" "$WORK_DIR/clock" "$WORK_DIR/enabled-policy.json"
assert_true "clock staging produces a service plugin from separate policy and manifest data" "ClockWidget::stage test_clock && jq -e '.id == \"os.clockwidget\" and .kinds == [\"service\"] and .entryPoints.service == \"ClockWidget.qml\"' '$WORK_DIR/clock/plugins/os.clockwidget/manifest.json' && cmp '$PROJECT_DIR/modules/conf/session/qml/ClockWidget.qml' '$WORK_DIR/clock/plugins/os.clockwidget/ClockWidget.qml'"
assert_true "disabling the clock removes its plugin without creating a bar" "jq '.clockWidget.enabled = false' '$PROJECT_DIR/modules/conf/session/data/policy.json' > '$WORK_DIR/disabled-policy.json' && jq --slurpfile policy '$WORK_DIR/disabled-policy.json' --slurpfile defaults '$PROJECT_DIR/modules/conf/session/data/shell.json' -f '$PROJECT_DIR/modules/conf/session/scripts/shell.jq' '$WORK_DIR/shell-new.json' | jq -e '([.plugins[] | if type == \"string\" then . else .id end] | index(\"os.clockwidget\") == null) and ([.bar.layout[][]] | length == 0)'"
assert_true "desktop tools and every child have functional menu icons" "jq -e 'all(.[]; .icon | type == \"string\" and length > 0)' '$PROJECT_DIR/modules/conf/session/data/desktop-apps.json'"
assert_true "desktop tools expose tiling applications instead of popup panels" "jq -e '.[\"desktop-tools.calendar\"].action==\"os app calendar\" and .[\"desktop-tools.weather\"].action==\"os app weather\" and .[\"desktop-tools.clock\"].action==\"os app clock\"' '$PROJECT_DIR/modules/conf/session/data/desktop-apps.json'"
assert_true "desktop clock widget is disabled in favor of the clock app" "jq -e '.clockWidget.enabled==false' '$PROJECT_DIR/modules/conf/session/data/policy.json'"
test_summary
