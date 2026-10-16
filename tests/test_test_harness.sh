#!/usr/bin/env bash

Os::tests::test_test_harness_sh::run() {
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
HARNESS_SANDBOX=$(mktemp -d)
trap 'rm -rf "$HARNESS_SANDBOX"' EXIT

cat > "$HARNESS_SANDBOX/scanner.sh" <<'FIXTURE'
#!/usr/bin/env bash
set -euo pipefail
source "$1"
scanner() {
    [[ "$2" == empty ]] || printf '%s\n' 'offending source'
    return "$1"
}
assert_no_offenders "scanner result" scanner "$2" "$3"
test_summary
FIXTURE
cat > "$HARNESS_SANDBOX/suite.sh" <<'FIXTURE'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '  fail simulated assertion'
printf '%s\n' 'Summary: Tests Executed: 1 | Passed: 0 | Failed: 1 | Warnings: 0'
exit 0
FIXTURE

test_section "Test Harness Failure Detection"
assert_true "successful empty scan passes" "bash '$HARNESS_SANDBOX/scanner.sh' '$SCRIPT_DIR/test_lib.sh' 0 empty"
assert_false "successful scan reporting an offender fails" "bash '$HARNESS_SANDBOX/scanner.sh' '$SCRIPT_DIR/test_lib.sh' 0 offender"
assert_false "failed empty scan never passes" "bash '$HARNESS_SANDBOX/scanner.sh' '$SCRIPT_DIR/test_lib.sh' 2 empty"
assert_false "partial output from a failed scan never passes" "bash '$HARNESS_SANDBOX/scanner.sh' '$SCRIPT_DIR/test_lib.sh' 2 offender"
assert_false "runner rejects failed assertions despite zero exit status" "bash '$SCRIPT_DIR/run-suite-list.sh' '$HARNESS_SANDBOX/suite.sh'"
printf '%s\n' '#!/bin/bash' 'exit 0' > "$HARNESS_SANDBOX/suite.sh"
assert_false "runner rejects suites without an assertion summary" "bash '$SCRIPT_DIR/run-suite-list.sh' '$HARNESS_SANDBOX/suite.sh'"
cat > "$HARNESS_SANDBOX/suite.sh" <<'FIXTURE'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '  pass simulated assertion'
printf '%s\n' 'Summary: Tests Executed: 2 | Passed: 2 | Failed: 0 | Warnings: 0'
FIXTURE
assert_false "runner rejects inflated assertion counts" "bash '$SCRIPT_DIR/run-suite-list.sh' '$HARNESS_SANDBOX/suite.sh'"
sed -i 's/Executed: 2 | Passed: 2/Executed: 1 | Passed: 1/' "$HARNESS_SANDBOX/suite.sh"
assert_true "runner accepts a consistent successful suite" "bash '$SCRIPT_DIR/run-suite-list.sh' '$HARNESS_SANDBOX/suite.sh'"
assert_false "runner rejects missing suites" "bash '$SCRIPT_DIR/run-suite-list.sh' '$HARNESS_SANDBOX/missing.sh'"
printf '%s\n' 'exit 7' >> "$HARNESS_SANDBOX/suite.sh"
assert_false "runner propagates nonzero exits after successful assertions" "bash '$SCRIPT_DIR/run-suite-list.sh' '$HARNESS_SANDBOX/suite.sh'"
mkdir -p "$HARNESS_SANDBOX/bin" "$HARNESS_SANDBOX/os" "$HARNESS_SANDBOX/empty"
printf '%s\n' '#!/bin/bash' 'exit 0' > "$HARNESS_SANDBOX/bin/pacman"
chmod 755 "$HARNESS_SANDBOX/bin/pacman"
assert_false "bare Arch container does not require installed desktop packages" "PATH='$HARNESS_SANDBOX/bin' desktop_runtime_available '$HARNESS_SANDBOX/missing'"
assert_true "installed Omarchy retains strict desktop runtime checks" "PATH='$HARNESS_SANDBOX/bin' desktop_runtime_available '$HARNESS_SANDBOX/os'"
assert_false "desktop runtime requires the native package manager" "PATH='$HARNESS_SANDBOX/empty' desktop_runtime_available '$HARNESS_SANDBOX/os'"
test_summary

}

Os::tests::test_test_harness_sh::run "$@"
