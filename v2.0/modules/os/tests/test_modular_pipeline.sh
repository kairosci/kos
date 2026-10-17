#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$(dirname "$PROJECT_DIR")")"
STAGE="$ROOT_DIR/scripts/lib/modules/36-os-cli.sh"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Modular Pipeline Architecture & Integrity"

assert_file_exists "stage 36-os-cli.sh exists" "$STAGE"
assert_file_executable "stage 36-os-cli.sh is executable" "$STAGE"
assert_file_contains "stage uses strict mode" "$STAGE" "set -euo pipefail"
assert_file_contains "setup.sh references stage 36-os-cli.sh" "$ROOT_DIR/scripts/setup.sh" "36-os-cli.sh"
assert_file_contains_literal "stage installs the dispatcher to the system path" "$ROOT_DIR/data/component/cli/installation.json" "/usr/local/bin/os"
assert_file_contains_literal "stage publishes the changelog to the shared path" "$ROOT_DIR/data/component/cli/installation.json" "/usr/share/os/CHANGELOG.md"
assert_file_contains_literal "stage reconciles per user copies" "$STAGE" "/home/*"
assert_file_contains_literal "stage routes user installs through user_as" "$STAGE" 'user_as "$_user"'
assert_file_contains "root pipeline suite tracks stage 36-os-cli.sh" "$ROOT_DIR/tests/test_modular_pipeline.sh" "36-os-cli.sh"
assert_file_contains "Makefile exposes the os target" "$ROOT_DIR/Makefile" "^os:"
assert_file_contains "Makefile exposes the changelog target" "$ROOT_DIR/Makefile" "^changelog:"
assert_file_contains "help lists the os target" "$ROOT_DIR/scripts/lib/help.sh" "make.os"
assert_file_contains "help lists the changelog target" "$ROOT_DIR/scripts/lib/help.sh" "make.changelog"

for lang in en it fr de es pt; do
    assert_file_contains "catalog $lang defines the os install message" "$ROOT_DIR/data/catalog/$lang.msg" "os.cli_installed="
done

test_summary
