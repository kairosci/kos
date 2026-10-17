#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$(dirname "$PROJECT_DIR")")"
source "$SCRIPT_DIR/test_lib.sh"
run_os() { lua -E "$ROOT_DIR/src/main.lua" "$ROOT_DIR" cli "$@"; }
assert_true "dispatcher prints localized usage" "run_os --help | grep -q 'os <group> <command>'"
assert_false "dispatcher rejects missing command" "run_os"
assert_true "dispatcher reads release narratives" "run_os changelog v1.3 | grep -q 'PowerShell downloader'"
assert_true "dispatcher accepts bare release numbers" "run_os changelog 1.2 | grep -q 'Release v1.2'"
assert_true "dispatcher reads the unreleased narrative" "run_os changelog unreleased | grep -q '## Unreleased'"
assert_false "dispatcher rejects an unknown release" "run_os changelog v9.9"
STUB_DIR=$(mktemp -d)
trap 'rm -rf "$STUB_DIR"' EXIT
cat > "$STUB_DIR/omarchy" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "native $*" "OMARCHY_PATH=$OMARCHY_PATH" "SESSION_BUS=${DBUS_SESSION_BUS_ADDRESS:-}"
exit "${OS_TEST_STATUS:-0}"
STUB
chmod 755 "$STUB_DIR/omarchy"
assert_true "native groups preserve arguments and runtime environment" "PATH='$STUB_DIR:$PATH' run_os theme 'two words' | grep -q 'native theme two words'"
assert_true "native groups receive the runtime root" "PATH='$STUB_DIR:$PATH' OMARCHY_PATH='$STUB_DIR' run_os commands | grep -q 'OMARCHY_PATH=$STUB_DIR'"
assert_true "native failures preserve exit status" "status=0; PATH='$STUB_DIR:$PATH' OS_TEST_STATUS=37 run_os commands || status=\$?; [[ \$status == 37 ]]"
assert_true "the essential starter serves help directly" "'$ROOT_DIR/script/os' --help | grep -q 'os <group> <command>'"
test_summary
