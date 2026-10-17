#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
WORK_DIR=$(mktemp -d)
trap 'rm -rf -- "$WORK_DIR"' EXIT
LOCALES="$PROJECT_DIR/modules/conf/session/data/locales"
QML_LIB="$PROJECT_DIR/modules/conf/session/scripts/qml.lua"
for language in en it fr de es pt; do
    assert_true "locale catalogue $language is valid JSON" "jq -e '.messages and .patterns' '$LOCALES/$language.json' > /dev/null"
done
assert_true "locale catalogues share the same message keys" "diff <(jq -r '.messages|keys[]' \"$LOCALES/en.json\"|sort) <(jq -r '.messages|keys[]' \"$LOCALES/it.json\"|sort) && diff <(jq -r '.messages|keys[]' \"$LOCALES/en.json\"|sort) <(jq -r '.messages|keys[]' \"$LOCALES/fr.json\"|sort) && diff <(jq -r '.messages|keys[]' \"$LOCALES/en.json\"|sort) <(jq -r '.messages|keys[]' \"$LOCALES/de.json\"|sort) && diff <(jq -r '.messages|keys[]' \"$LOCALES/en.json\"|sort) <(jq -r '.messages|keys[]' \"$LOCALES/es.json\"|sort) && diff <(jq -r '.messages|keys[]' \"$LOCALES/en.json\"|sort) <(jq -r '.messages|keys[]' \"$LOCALES/pt.json\"|sort)"
assert_true "locale catalogues share the same patterns" "for l in it fr de es pt; do cmp -s <(jq -c '.patterns[].match' \"$LOCALES/en.json\") <(jq -c '.patterns[].match' \"$LOCALES/\$l.json\") || exit 1; done"
assert_true "locale catalogues leave no message empty" "! jq -er '.messages[] | select(length == 0)' $LOCALES/*.json"
assert_true "locale patterns carry a match and a replacement" "jq -e '.patterns | length > 0 and all(.[]; (.match | length > 0) and (.value | length > 0))' '$LOCALES/en.json' > /dev/null"
cat > "$WORK_DIR/lexer.lua" <<LUA
local qml = dofile("$QML_LIB")
local function check(name, source, expected)
    local cleaned = qml.clean(source)
    assert(not cleaned:find(expected, 1, true), name .. " leaked comment")
    assert(cleaned:find("https://example.org/x?q=1", 1, true), name .. " broke an URL")
end
check("line", 'text: "Hi" // note\nurl: "https://example.org/x?q=1"', "note")
check("block", 'text: "Hi" /* note */\nurl: "https://example.org/x?q=1"', "note")
local lexed = qml.localize('text: "Apps"\nurl: "https://example.org/x?q=1"\ntext: root.title\ntext: queueRow.name\ntext: "Queue (" + count + ")"')
assert(lexed:find('SessionI18n.text("Apps")', 1, true), "static string not wrapped")
assert(not lexed:find('SessionI18n.text(root.title)', 1, true), "media title must stay raw")
assert(not lexed:find('SessionI18n.text(queueRow', 1, true), "queue content must stay raw")
assert(lexed:find("https://example.org/x?q=1", 1, true), "URL broken by localization")
local ternary = qml.localize('text: active ? "Yes" : "No"\ntooltipText: model.name + " suffix"')
assert(ternary:find("SessionI18n.text", 1, true), "ternary binding lost")
local dates = qml.localize('text: Qt.formatDate(d, "dd MMM")\ntext: Qt.formatDateTime(t, Qt.locale("en_US"))')
assert(dates:find("SessionI18n.formatDate(", 1, true), "formatDate not routed")
assert(dates:find("SessionI18n.formatDateTime(", 1, true), "formatDateTime not routed")
assert(dates:find("SessionI18n.locale", 1, true), "hardcoded locale not routed")
assert(not dates:find("en_US", 1, true), "hardcoded locale leaked")
local single = qml.localize("text: Qt.formatDateTime(t, Qt.locale('en_US'))")
assert(single:find("SessionI18n.locale", 1, true), "single quoted locale not routed")
local regex = qml.localize('text: "Hi"\nproperty var re: /ab+c/gi\ntext: a / b')
assert(regex:find("/ab+c/gi", 1, true), "regex broken")
assert(regex:find("a / b", 1, true), "division broken")
local multiline = qml.localize('text: first +\n  second')
assert(multiline:find("SessionI18n.text(first", 1, true), "multiline binding lost")
local member = qml.localize('label.text: "Hi"')
assert(not member:find("SessionI18n", 1, true), "member access wrongly wrapped")
print("session-qml-lexer-valid")
LUA
assert_true "QML lexer keeps URLs and regex while wrapping display bindings" "lua '$WORK_DIR/lexer.lua' | grep -q session-qml-lexer-valid"
assert_true "menu adapter preserves app names and shared confirm dialog" "grep -q 'row.kind === \"app\"' '$PROJECT_DIR/modules/conf/session/scripts/prepare-menu.lua' && grep -q 'ControlConfirmDialog' '$PROJECT_DIR/modules/conf/session/scripts/prepare-menu.lua'"
assert_true "ControlConfirmDialog gains the implicit Ui import" "grep -q 'import qs.Ui' '$PROJECT_DIR/modules/conf/session/install.sh'"
assert_true "shell startup uses a markerless line with legacy cleanup" "grep -q 'install_user_line' '$PROJECT_DIR/modules/conf/session/install.sh' && grep -q 'remove_shell_block' '$PROJECT_DIR/modules/conf/session/install.sh' && ! grep -q 'install_shell_block.*quickshell' '$PROJECT_DIR/modules/conf/session/install.sh'"
assert_true "installer localizes staged menus from the resolved catalogue" "grep -q 'translations.json' '$PROJECT_DIR/modules/conf/session/install.sh'"
if command -v qs >/dev/null 2>&1; then
    mkdir -p "$WORK_DIR/i18n/os/session/data" "$WORK_DIR/i18n/config"
    jq -n --arg language it --slurpfile catalogue "$LOCALES/it.json" '{language:$language,messages:$catalogue[0].messages,patterns:$catalogue[0].patterns,folded:($catalogue[0].messages|to_entries|map({key:(.key|ascii_downcase),value:.value})|from_entries)}' > "$WORK_DIR/i18n/os/session/data/translations.json"
    cp "$PROJECT_DIR/modules/conf/session/qml/SessionI18n.qml" "$WORK_DIR/i18n/config/"
    printf 'singleton SessionI18n 1.0 SessionI18n.qml\n' > "$WORK_DIR/i18n/config/qmldir"
    cat > "$WORK_DIR/i18n/config/shell.qml" <<'QML'
import QtQuick
import Quickshell
import "."
ShellRoot {
    Timer {
        interval: 50
        running: true
        repeat: true
        property int ticks: 0
        onTriggered: {
            ticks += 1
            if (SessionI18n.language === "it" || ticks > 40) {
                let checks = [
                    SessionI18n.text("Apps").length > 0,
                    SessionI18n.text("No matches for “zzz”").indexOf("zzz") !== -1,
                    SessionI18n.text("Do you want to uninstall Demo?").length > 0,
                    SessionI18n.text("Queue (3)").indexOf("3") !== -1,
                    SessionI18n.text("My custom entry") === "My custom entry",
                    SessionI18n.text("") === "",
                    SessionI18n.language === "it"
                ]
                let ok = true
                for (let i = 0; i < checks.length; ++i) if (!checks[i]) ok = false
                console.log(ok ? "session-i18n-valid" : "session-i18n-invalid")
                Qt.quit()
            }
        }
    }
}
QML
    assert_true "real SessionI18n resolves messages and patterns with fallback" "env -u QS_CONFIG_PATH QT_QPA_PLATFORM=offscreen XDG_DATA_HOME='$WORK_DIR/i18n' timeout 10 qs -p '$WORK_DIR/i18n/config/shell.qml' 2>&1 | grep -q session-i18n-valid"
else
    assert_warn "SessionI18n runtime check requires Quickshell" "command -v qs"
fi
test_summary
