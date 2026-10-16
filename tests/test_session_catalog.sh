#!/usr/bin/env bash

Os::tests::test_session_catalog_sh::run() {
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
WORK_DIR=$(mktemp -d)
trap 'rm -rf -- "$WORK_DIR"' EXIT
if ! command -v qs >/dev/null; then
    assert_warn "Quickshell catalogue integration requires the Quickshell test dependency" "command -v qs"
    test_summary
    exit 0
fi
mkdir -p "$WORK_DIR/"{bin,data/os/session/data,empty,config}
mkdir -p "$WORK_DIR/config/catalog"
cp "$PROJECT_DIR/modules/conf/session/qml/AppCatalog.qml" "$WORK_DIR/config/catalog/"
cp "$SCRIPT_DIR/qml/SessionCatalog.qml" "$WORK_DIR/config/shell.qml"
cp -r "$SCRIPT_DIR/data/session/applications" "$WORK_DIR/data/"
cp "$SCRIPT_DIR/data/session/launcher.hides" "$WORK_DIR/data/os/session/data/"
cat > "$WORK_DIR/bin/uwsm-app" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\0' "$@" > "$SESSION_LAUNCH_LOG"
SH
chmod +x "$WORK_DIR/bin/uwsm-app"
run_catalog() {
    env -u QS_CONFIG_PATH -u QS_CONFIG_NAME -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen \
        PATH="$WORK_DIR/bin:$PATH" XDG_DATA_HOME="$WORK_DIR/data" \
        XDG_DATA_DIRS="$WORK_DIR/empty" XDG_CONFIG_HOME="$WORK_DIR/config" \
        SESSION_LAUNCH_LOG="$WORK_DIR/launch.log" \
        timeout 10 qs -p "$WORK_DIR/config/shell.qml" > "$WORK_DIR/qml.log" 2>&1
}
assert_true "real Quickshell catalogue reads desktop entries and applies hidden filters" "run_catalog && grep -q 'session-appcatalog-valid' '$WORK_DIR/qml.log'"
for attempt in {1..20}; do
    [[ ! -f "$WORK_DIR/launch.log" ]] || break
    sleep 0.05
done
printf '%s\0' -- gtk-launch visible.desktop > "$WORK_DIR/expected.log"
assert_true "application launch preserves desktop entry resolution through uwsm" "cmp '$WORK_DIR/expected.log' '$WORK_DIR/launch.log'"
if [[ "$TESTS_FAILED" -gt 0 ]]; then cat "$WORK_DIR/qml.log"; fi
test_summary

}

Os::tests::test_session_catalog_sh::run "$@"
