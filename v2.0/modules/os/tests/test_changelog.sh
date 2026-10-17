#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$(dirname "$PROJECT_DIR")")"
CHANGELOG="$ROOT_DIR/CHANGELOG.md"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Changelog Narrative"

assert_file_exists "CHANGELOG.md exists at the repository root" "$CHANGELOG"
assert_file_contains "changelog declares its single source role" "$CHANGELOG" "single narrative source"
assert_file_contains "changelog tracks the unreleased dispatcher work" "$CHANGELOG" "## Unreleased"
assert_file_contains "changelog narrates release v1.4" "$CHANGELOG" "## Release v1.4"
assert_file_contains "changelog narrates release v1.3" "$CHANGELOG" "## Release v1.3"
assert_file_contains "changelog narrates release v1.2" "$CHANGELOG" "## Release v1.2"
assert_file_contains "changelog narrates release v1.1" "$CHANGELOG" "## Release v1.1"
assert_file_contains "changelog narrates release v1.0" "$CHANGELOG" "## Release v1.0"
assert_true "changelog uses prose instead of lists" "! grep -qE '^[[:space:]]*([-*+][[:space:]]+|[0-9]+[.)][[:space:]]+)' '$CHANGELOG'"
assert_true "dispatcher section matches the changelog file" "OS_CHANGELOG='$CHANGELOG' '$ROOT_DIR/script/os' changelog v1.0 | grep -q 'Release v1.0'"

test_summary
