#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
WORK_DIR=$(mktemp -d)
trap 'rm -rf -- "$WORK_DIR"' EXIT
CLEAN="$PROJECT_DIR/modules/conf/session/data/clean.lua"
cat > "$WORK_DIR/input.lua" <<'LUA'
-- Introductory comment
local text = "keep -- inside a string"
local block = [=[line one


line four -- literal
]=]
--[==[ discard this long comment ]==]
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
assert_true "Lua cleaner parses comments without changing string contents" "lua '$CLEAN' '$WORK_DIR/input.lua' '$WORK_DIR/state.lua' '$WORK_DIR/state-new.lua' > '$WORK_DIR/clean.lua' && lua '$WORK_DIR/clean.lua'"
assert_true "Lua cleaner removes narrative and block comments" "! grep -q 'Introductory\|discard this' '$WORK_DIR/clean.lua'"
assert_true "Lua cleanup is idempotent" "lua '$CLEAN' '$WORK_DIR/clean.lua' '$WORK_DIR/state-new.lua' '$WORK_DIR/state-again.lua' > '$WORK_DIR/again.lua' && cmp '$WORK_DIR/clean.lua' '$WORK_DIR/again.lua' && cmp '$WORK_DIR/state-new.lua' '$WORK_DIR/state-again.lua'"
cat "$WORK_DIR/clean.lua" > "$WORK_DIR/updated.lua"
cat >> "$WORK_DIR/updated.lua" <<'LUA'
-- os locale (managed)
local layout = "fr"
-- end os locale (managed)
LUA
assert_true "managed policy updates replace the previous commentless body" "lua '$CLEAN' '$WORK_DIR/updated.lua' '$WORK_DIR/state-new.lua' '$WORK_DIR/state-updated.lua' > '$WORK_DIR/updated-clean.lua' && [[ \$(grep -c 'local layout' '$WORK_DIR/updated-clean.lua') == 1 ]] && grep -q 'local layout = \"fr\"' '$WORK_DIR/updated-clean.lua'"
cat >> "$WORK_DIR/updated.lua" <<'LUA'
-- os locale (managed)
local layout = "de"
-- end os locale (managed)
LUA
assert_true "repeated managed blocks keep only the latest policy" "lua '$CLEAN' '$WORK_DIR/updated.lua' '$WORK_DIR/state-new.lua' > '$WORK_DIR/duplicate-clean.lua' && [[ \$(grep -c 'local layout' '$WORK_DIR/duplicate-clean.lua') == 1 ]] && grep -q 'local layout = \"de\"' '$WORK_DIR/duplicate-clean.lua'"
printf 'local invalid =\n' > "$WORK_DIR/invalid.lua"
assert_true "invalid Lua is rejected" "! lua '$CLEAN' '$WORK_DIR/invalid.lua'"
printf 'require("unknown.omarchy.module")\n' > "$WORK_DIR/unknown.lua"
assert_true "unknown runtime references fail instead of being removed" "! lua '$CLEAN' '$WORK_DIR/unknown.lua'"
cat > "$WORK_DIR/native.lua" <<'LUA'
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")
require("default.hypr.omarchy")
require("default.hypr.toggles")
local omarchy_gdk_scale = 2
local command = "omarchy-cmd-terminal-cwd"
LUA
assert_true "native bootstrap becomes an OS adapter without changing monitor scale" "lua '$CLEAN' '$WORK_DIR/native.lua' > '$WORK_DIR/native-clean.lua' && ! grep -qi omarchy '$WORK_DIR/native-clean.lua' && grep -q 'desktop.defaults()' '$WORK_DIR/native-clean.lua' && grep -q 'local gdk_scale = 2' '$WORK_DIR/native-clean.lua' && grep -q 'os cmd terminal cwd' '$WORK_DIR/native-clean.lua'"
printf '%s\n' '{"idle":{"lock":300},"bar":{"position":"bottom","layout":{"left":["omarchy.menu","omarchy.workspaces"],"center":[{"id":"omarchy.clock","format":"HH:mm"}],"right":["personal.widget"]}},"plugins":["personal.plugin"]}' > "$WORK_DIR/shell.json"
assert_true "menu clone keeps personal widgets and the idle policy" "jq -f '$PROJECT_DIR/modules/conf/session/data/shell.jq' '$WORK_DIR/shell.json' > '$WORK_DIR/shell-new.json' && jq -e '.idle.lock == 300 and .bar.position == \"bottom\" and .bar.layout.right == [\"personal.widget\"] and .bar.layout.center[0].format == \"HH:mm\" and .plugins == [\"personal.plugin\",{id:\"os.menu\"}]' '$WORK_DIR/shell-new.json'"
assert_true "menu clone installation is idempotent" "jq -f '$PROJECT_DIR/modules/conf/session/data/shell.jq' '$WORK_DIR/shell-new.json' > '$WORK_DIR/shell-again.json' && cmp '$WORK_DIR/shell-new.json' '$WORK_DIR/shell-again.json'"
assert_true "bar actions account for the inverted native bar off flag" "jq -e '.[\"bar.show\"].action == \"os toggle bar off\" and .[\"bar.hide\"].action == \"os toggle bar on\"' '$PROJECT_DIR/modules/conf/session/data/menu.json'"
mkdir -p "$WORK_DIR/homes/tester/.config/"{hypr,omarchy/plugins/os.menu,omarchy/extensions} "$WORK_DIR/trusted"
for file in Menu.qml MenuModel.js manifest.json; do
    printf 'fixture\n' > "$WORK_DIR/homes/tester/.config/omarchy/plugins/os.menu/$file"
done
printf '{}\n' > "$WORK_DIR/homes/tester/.config/omarchy/extensions/os-menu.json"
printf '{}\n' > "$WORK_DIR/homes/tester/.config/omarchy/shell.json"
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
            if [[ "${SESSION_TEST_CHANGE:-0}" == 1 ]]; then
                printf 'changed\n' >> "$SESSION_TEST_ROOT/homes/tester/.config/omarchy/plugins/os.menu/Menu.qml"
            fi
            ;;
        hyprctl)
            if [[ "$2" == configerrors && "${SESSION_TEST_ERRORS:-0}" == 1 ]]; then
                printf 'invalid configuration\n'
            fi
            ;;
        *) return 1 ;;
    esac
}
omarchy_as() {
    printf '%s\n' "$*" >> "$SESSION_TEST_ROOT/commands.log"
    printf 'ok\n'
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
test_summary
