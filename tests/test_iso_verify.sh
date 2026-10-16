#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test_lib.sh"

test_section "ISO Verification Script"

VERIFY_SCRIPT="$PROJECT_DIR/modules/iso/scripts/verify-iso.sh"
ISO_WORKFLOW="$PROJECT_DIR/.github/workflows/iso.yml"

assert_file_exists "verification script exists" "$VERIFY_SCRIPT"
assert_file_executable "verification script is executable" "$VERIFY_SCRIPT"
assert_true "verification script passes syntax check" "bash -n '$VERIFY_SCRIPT'"
assert_file_contains "verification script uses strict mode" "$VERIFY_SCRIPT" "set -euo pipefail"
assert_file_contains "verification script sources the i18n library" "$VERIFY_SCRIPT" "lib/i18n.sh"
assert_file_contains "verification script initializes i18n" "$VERIFY_SCRIPT" "i18n_init"
assert_true "verification script shows usage" "bash '$VERIFY_SCRIPT' --help"
assert_true "verification script rejects missing arguments" "! bash '$VERIFY_SCRIPT' --iso /nonexistent.iso"
assert_true "verification script rejects a missing image" "! bash '$VERIFY_SCRIPT' --iso /nonexistent.iso --ref HEAD"
assert_true "verification script rejects an invalid ref" "! bash '$VERIFY_SCRIPT' --iso '$VERIFY_SCRIPT' --ref refs/nonexistent/ref"
assert_true "verification script rejects an invalid expected commit" "! bash '$VERIFY_SCRIPT' --iso '$VERIFY_SCRIPT' --ref HEAD --expected-commit notasha"
assert_file_contains "verification script extracts the bundled tree" "$VERIFY_SCRIPT" "/opt/os"
assert_file_contains "verification script checks the release marker" "$VERIFY_SCRIPT" "os-release.txt"
assert_file_contains "verification script compares materialized content" "$VERIFY_SCRIPT" "diff -qr -x .gitkeep"

assert_file_contains "ISO workflow builds the image in its own job" "$ISO_WORKFLOW" "^  build:"
assert_file_contains "ISO workflow verifies in a separate job" "$ISO_WORKFLOW" "^  verify:"
assert_file_contains "ISO workflow publishes in a separate job" "$ISO_WORKFLOW" "^  release:"
assert_file_contains "ISO verify job waits for the build" "$ISO_WORKFLOW" "needs: build"
assert_file_contains "ISO release job waits for verification" "$ISO_WORKFLOW" "needs: .build, verify."
assert_file_contains "ISO build shares the image through an artifact" "$ISO_WORKFLOW" "upload-artifact@"
assert_file_contains "ISO verify job fetches the image artifact" "$ISO_WORKFLOW" "download-artifact@"
assert_file_contains "ISO verify job runs the verification script" "$ISO_WORKFLOW" "verify-iso.sh"
assert_file_contains_literal "ISO verify job pins the expected build commit" "$ISO_WORKFLOW" "--expected-commit"

test_summary
