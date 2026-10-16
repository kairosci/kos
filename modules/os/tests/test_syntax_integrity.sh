#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Script Syntax & Code Integrity"

for sh_file in "$PROJECT_DIR"/bin/* "$PROJECT_DIR"/scripts/lib/*.sh "$PROJECT_DIR"/tests/*.sh; do
    [[ -f "$sh_file" ]] || continue
    fname=$(basename "$sh_file")
    assert_true "syntax check: $fname" "bash -n '$sh_file'"
done

assert_file_executable "bin/os is executable" "$PROJECT_DIR/bin/os"
assert_file_contains "bin/os uses strict mode" "$PROJECT_DIR/bin/os" "set -euo pipefail"
assert_file_executable "tests/run-all.sh is executable" "$PROJECT_DIR/tests/run-all.sh"

for helper in "$PROJECT_DIR"/bin/*; do
    [[ -f "$helper" ]] || continue
    hname=$(basename "$helper")
    assert_file_executable "helper $hname is executable" "$helper"
    assert_file_contains "helper $hname uses strict mode" "$helper" "set -euo pipefail"
done

test_summary
