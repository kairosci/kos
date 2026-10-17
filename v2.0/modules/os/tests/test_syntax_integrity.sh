#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$(dirname "$PROJECT_DIR")")"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Script Syntax & Code Integrity"

for sh_file in "$PROJECT_DIR"/bin/* "$PROJECT_DIR"/scripts/lib/*.sh "$PROJECT_DIR"/tests/*.sh; do
    [[ -f "$sh_file" ]] || continue
    fname=$(basename "$sh_file")
    assert_true "syntax check: $fname" "bash -n '$sh_file'"
done

assert_file_executable "bin/os is executable" "$ROOT_DIR/script/os"
assert_file_contains "bin/os uses strict mode" "$ROOT_DIR/script/os" "set -euo pipefail"
assert_file_exists "Lua suite entry point exists" "$PROJECT_DIR/../../tests/main.lua"

for helper in "$PROJECT_DIR"/bin/*; do
    [[ -f "$helper" ]] || continue
    hname=$(basename "$helper")
    assert_file_executable "helper $hname is executable" "$helper"
    assert_file_contains "helper $hname uses strict mode" "$helper" "set -euo pipefail"
done

test_summary
