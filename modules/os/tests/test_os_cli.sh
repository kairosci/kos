#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OS_BIN="$PROJECT_DIR/bin/os"
ROOT_DIR="$(dirname "$(dirname "$PROJECT_DIR")")"

source "$SCRIPT_DIR/test_lib.sh"

test_section "os Dispatcher Behavior"

assert_file_contains_literal "dispatcher forwards every group to omarchy" "$OS_BIN" 'exec omarchy "$@"'
assert_file_contains_literal "dispatcher resolves the runtime path" "$OS_BIN" 'OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"'
assert_file_contains_literal "dispatcher restores the runtime directory" "$OS_BIN" 'XDG_RUNTIME_DIR="/run/user/$uid"'
assert_file_contains_literal "dispatcher restores the session bus" "$OS_BIN" 'DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus"'
assert_file_contains_literal "dispatcher falls back to the system runtime path" "$OS_BIN" 'PATH="$OMARCHY_PATH/bin:$PATH"'
assert_file_contains "dispatcher keeps the i18n fallback explicit" "$OS_BIN" 'OS_I18N_FALLBACK=1'
assert_file_contains_literal "dispatcher serves the changelog" "$OS_BIN" 'os_changelog "$@"'
assert_file_contains "dispatcher reports the versions" "$OS_BIN" 'os dispatcher 1.0.0'
assert_false "dispatcher never suppresses failures blindly" "grep -qE '\\|\\|[[:space:]]*true\\b' '$OS_BIN'"
assert_true "dispatcher prints usage" "'$OS_BIN' --help | grep -q 'os <group> <command>'"
assert_true "dispatcher rejects missing command" "! '$OS_BIN' >/dev/null 2>&1"
assert_true "dispatcher reads the release narrative" "OS_CHANGELOG='$ROOT_DIR/CHANGELOG.md' '$OS_BIN' changelog v1.3 | grep -q 'PowerShell downloader'"
assert_true "dispatcher accepts a bare release number" "OS_CHANGELOG='$ROOT_DIR/CHANGELOG.md' '$OS_BIN' changelog 1.2 | grep -q 'Release v1.2'"
assert_true "dispatcher reads the unreleased narrative" "OS_CHANGELOG='$ROOT_DIR/CHANGELOG.md' '$OS_BIN' changelog unreleased | grep -q '## Unreleased'"
assert_true "dispatcher rejects an unknown release" "! OS_CHANGELOG='$ROOT_DIR/CHANGELOG.md' '$OS_BIN' changelog v9.9 >/dev/null 2>&1"
if [[ -x /usr/share/omarchy/bin/omarchy ]]; then
    OUTSIDE_PATH_TMP="$(mktemp)"
    OUTSIDE_PATH_RC=0
    env -i HOME="$HOME" PATH='/usr/bin:/bin' "$OS_BIN" commands >"$OUTSIDE_PATH_TMP" 2>/dev/null || OUTSIDE_PATH_RC=$?
    assert_true "dispatcher finds omarchy outside PATH" "[[ '$OUTSIDE_PATH_RC' -eq 0 ]] && grep -q 'omarchy theme list' '$OUTSIDE_PATH_TMP'"
    rm -f "$OUTSIDE_PATH_TMP"
fi

STUB_DIR=$(mktemp -d)
trap 'rm -rf "$STUB_DIR"' EXIT
cat > "$STUB_DIR/omarchy" << 'STUB'
#!/bin/bash
printf '%s\n' "stub omarchy $*"
printf '%s\n' "OMARCHY_PATH=$OMARCHY_PATH"
STUB
chmod +x "$STUB_DIR/omarchy"
assert_true "dispatcher delegates groups with the prepared environment" "PATH='$STUB_DIR:$PATH' '$OS_BIN' theme list | grep -q 'stub omarchy theme list'"
assert_true "dispatcher exposes discovery through the stub" "PATH='$STUB_DIR:$PATH' '$OS_BIN' commands --check | grep -q 'stub omarchy commands --check'"

test_summary
