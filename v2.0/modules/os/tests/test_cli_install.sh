#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$(dirname "$PROJECT_DIR")")"
source "$SCRIPT_DIR/test_lib.sh"
WORK_DIR=$(mktemp -d)
trap 'rm -rf -- "$WORK_DIR"' EXIT
mkdir -p "$WORK_DIR/project/scripts/lib/modules"
sed 's/\$EUID/0/g' "$ROOT_DIR/scripts/setup.sh" > "$WORK_DIR/project/scripts/setup.sh"
cp "$ROOT_DIR/scripts/lib/i18n.sh" "$ROOT_DIR/scripts/lib/target-user.sh" "$WORK_DIR/project/scripts/lib/"
cp -r "$ROOT_DIR/data/catalog" "$WORK_DIR/project/scripts/lib/messages"
printf 'root_setup_persistent() { return 0; }\n' > "$WORK_DIR/project/scripts/lib/root-recovery.sh"
printf '[[ "${1:-}" == --functions-only ]] || exit 81\nprintf "helpers\\n" >> "$CLI_TEST_TRACE"\n' > "$WORK_DIR/project/scripts/lib/modules/00-env.sh"
printf 'printf "cli\\n" >> "$CLI_TEST_TRACE"\n' > "$WORK_DIR/project/scripts/lib/modules/36-os-cli.sh"
assert_true "CLI scope reaches only session helpers and its owned installer" "OS_LOG_STDOUT=1 CLI_TEST_TRACE='$WORK_DIR/trace' bash '$WORK_DIR/project/scripts/setup.sh' --scope cli && cmp -s '$WORK_DIR/trace' <(printf 'helpers\\ncli\\n')"
assert_false "CLI scope refuses unrelated full setup options" "OS_LOG_STDOUT=1 CLI_TEST_TRACE='$WORK_DIR/trace' bash '$WORK_DIR/project/scripts/setup.sh' --scope cli --reset-snapshots"
test_summary
