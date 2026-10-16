#!/bin/bash

Os::modules::os::tests::test_idempotency_safety_sh::run() {

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$(dirname "$PROJECT_DIR")")"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Automation Idempotency & Safety Rules"

assert_false "No raw '|| true' failure suppression in dispatcher" "grep -qE '\\|\\|[[:space:]]*true\\b' '$PROJECT_DIR/bin/os'"
assert_false "No raw '|| true' failure suppression in stage" "grep -qE '\\|\\|[[:space:]]*true\\b' '$ROOT_DIR/scripts/lib/modules/36-os-cli.sh'"
assert_false "No raw '|| true' failure suppression in tests" "grep --exclude=test_idempotency_safety.sh -qE '\\|\\|[[:space:]]*true\\b' '$PROJECT_DIR'/tests/*.sh"

check_no_hardcoded_user_paths() {
    local count
    count=$(grep -rnE '/home/[a-zA-Z0-9_-]+/' "$PROJECT_DIR/bin/os" "$ROOT_DIR/scripts/lib/modules/36-os-cli.sh" 2>/dev/null | grep -cvE '(/home/\*|/home/\$|PRIMARY_USER)' || :)
    [[ "$count" -eq 0 ]]
}

assert_true "No hardcoded specific user home paths in dispatcher and stage" "check_no_hardcoded_user_paths"

test_summary

}

Os::modules::os::tests::test_idempotency_safety_sh::run "$@"
