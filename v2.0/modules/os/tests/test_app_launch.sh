#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$(dirname "$PROJECT_DIR")")"
source "$SCRIPT_DIR/test_lib.sh"
WORK_DIR=$(mktemp -d)
trap 'rm -rf -- "$WORK_DIR"' EXIT
mkdir -p "$WORK_DIR/bin" "$WORK_DIR/home" "$WORK_DIR/data/applications" "$WORK_DIR/system/applications" "$WORK_DIR/native/default/bash"
printf 'touch "$APP_TEST_NATIVE"\n' > "$WORK_DIR/native/default/bash/env-bootstrap"
cat > "$WORK_DIR/bin/xdg-settings" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ -z "${BROWSER:-}" ]] || exit 42
[[ "${APP_TEST_QUERY_FAIL:-0}" == 0 ]] || exit 43
printf '%s\n' "${APP_TEST_BROWSER-browser.desktop}"
SH
cat > "$WORK_DIR/bin/xdg-mime" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ "${APP_TEST_QUERY_FAIL:-0}" == 0 ]] || exit 43
case "$3" in
    x-scheme-handler/https) printf 'fallback.desktop\n' ;;
    text/plain) printf 'editor.desktop\n' ;;
    inode/directory) printf 'files.desktop\n' ;;
    *) exit 44 ;;
esac
SH
cat > "$WORK_DIR/bin/uwsm-app" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\0' "$@" > "$APP_TEST_ARGV"
[[ "${OMARCHY_PATH:-}" == "$APP_TEST_RUNTIME" ]] || exit 45
exit "${APP_TEST_LAUNCH_STATUS:-0}"
SH
cat > "$WORK_DIR/bin/omarchy" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
touch "$APP_TEST_NATIVE"
exit 46
SH
chmod 755 "$WORK_DIR/bin/"*
for desktop in browser fallback editor files os.settings; do
    printf '[Desktop Entry]\nType=Application\nName=Fixture\nExec=fixture %%U\n' > "$WORK_DIR/system/applications/$desktop.desktop"
done
cat >> "$WORK_DIR/system/applications/browser.desktop" <<'DESKTOP'
Actions=new-private-window;
[Desktop Action new-private-window]
Exec=fixture --incognito %U
DESKTOP
run_app() {
    env -i HOME="$WORK_DIR/home" PATH="$WORK_DIR/bin:/usr/bin:/bin" XDG_CONFIG_HOME="$WORK_DIR/config" \
        XDG_DATA_HOME="$WORK_DIR/data" XDG_DATA_DIRS="$WORK_DIR/system" XDG_STATE_HOME="$WORK_DIR/state" \
        OMARCHY_PATH="$WORK_DIR/native" APP_TEST_RUNTIME="$WORK_DIR/native" APP_TEST_NATIVE="$WORK_DIR/native-used" \
        APP_TEST_ARGV="$WORK_DIR/argv" APP_TEST_QUERY_FAIL="${APP_TEST_QUERY_FAIL:-0}" \
        APP_TEST_BROWSER="${APP_TEST_BROWSER-browser.desktop}" APP_TEST_LAUNCH_STATUS="${APP_TEST_LAUNCH_STATUS:-0}" \
        BROWSER=untrusted-browser OS_LANG=en lua -E "$ROOT_DIR/src/main.lua" "$ROOT_DIR" cli app "$@"
}
assert_true "browser resolution ignores BROWSER and preserves the exact URL argument" "run_app --resolve browser 'https://example.org/a b?x=1&y=2' > '$WORK_DIR/resolve.json' && jq -e '.desktop==\"browser.desktop\" and .argv==[\"uwsm-app\",\"--\",\"browser.desktop\",\"https://example.org/a b?x=1&y=2\"]' '$WORK_DIR/resolve.json'"
assert_true "read only resolution never starts an app or loads the native runtime" "[[ ! -e '$WORK_DIR/argv' && ! -e '$WORK_DIR/native-used' ]]"
assert_true "private browser uses the declared desktop action" "run_app --resolve browser --private 'https://example.org' | jq -e '.private and .desktop==\"browser.desktop:new-private-window\" and .argv[3]==\"https://example.org\"'"
assert_true "browser falls back to its HTTPS association when the browser setting is empty" "APP_TEST_BROWSER='' run_app --resolve browser | jq -e '.desktop==\"fallback.desktop\"'"
assert_false "private requests never fall back to a normal browser window" "APP_TEST_BROWSER=fallback.desktop run_app browser --private"
assert_false "failed default queries prevent application launch" "APP_TEST_QUERY_FAIL=1 run_app browser"
assert_false "invalid desktop identifiers are rejected" "APP_TEST_BROWSER='../browser.desktop' run_app browser"
assert_false "unknown arguments are rejected before an application starts" "run_app browser --incognito"
assert_false "unknown application roles are rejected" "run_app missing"
assert_true "graphical editor uses the MIME preference" "run_app --resolve editor '/tmp/file with spaces' | jq -e '.desktop==\"editor.desktop\" and .argv[3]==\"/tmp/file with spaces\"'"
assert_true "file manager uses the directory MIME preference" "run_app --resolve files | jq -e '.desktop==\"files.desktop\"'"
assert_true "settings resolves the unified application without the native desktop runtime" "run_app --resolve settings | jq -e '.desktop==\"os.settings.desktop\"'"
printf '[Desktop Entry]\nType=Application\nHidden=true\nExec=fixture\n' > "$WORK_DIR/data/applications/browser.desktop"
assert_false "a hidden user override prevents launching the system entry" "run_app browser"
printf '[Desktop Entry]\nType=Application\nExec=fixture-user\n' > "$WORK_DIR/data/applications/browser.desktop"
assert_true "user desktop entries take priority over system entries" "run_app --resolve browser | jq -e --arg path '$WORK_DIR/data/applications/browser.desktop' '.desktopFile==\$path'"
rm "$WORK_DIR/data/applications/browser.desktop"
mkdir -p "$WORK_DIR/system/applications/nested"
mv "$WORK_DIR/system/applications/browser.desktop" "$WORK_DIR/system/applications/nested/browser.desktop"
assert_true "nested desktop entry identifiers are resolved" "APP_TEST_BROWSER=nested-browser.desktop run_app --resolve browser | jq -e '.desktopFile|endswith(\"/nested/browser.desktop\")'"
mv "$WORK_DIR/system/applications/nested/browser.desktop" "$WORK_DIR/system/applications/browser.desktop"
assert_true "application launch preserves the argument vector without shell expansion" "run_app files '\$(touch not-executed)' && cmp -s '$WORK_DIR/argv' <(printf '%s\\0' -- files.desktop '\$(touch not-executed)') && [[ ! -e '$WORK_DIR/native-used' ]]"
launch_failure_propagates() {
    local status=0
    APP_TEST_LAUNCH_STATUS=37 run_app settings || status=$?
    [[ "$status" == 37 ]]
}
assert_true "launcher failures preserve their original exit status" "launch_failure_propagates"
mkdir -p "$WORK_DIR/installed"
cp -a "$ROOT_DIR/src" "$ROOT_DIR/data" "$ROOT_DIR/script" "$WORK_DIR/installed/"
assert_true "installed layout loads its Lua runtime and policy without repository paths" "env -i HOME='$WORK_DIR/home' PATH='$WORK_DIR/bin:/usr/bin:/bin' XDG_DATA_DIRS='$WORK_DIR/system' lua -E '$WORK_DIR/installed/src/main.lua' '$WORK_DIR/installed' cli app --resolve settings | jq -e '.role==\"settings\"'"
assert_true "native app diagnostics are localized" "OS_LANG=it lua -E '$ROOT_DIR/src/main.lua' '$ROOT_DIR' cli app --help | grep -q '^Uso:'"
assert_false "migration readiness remains blocked after implementing only app launchers" "bash '$ROOT_DIR/scripts/lib/arch-migration.sh' --check"
test_summary
