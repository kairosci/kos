#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export THEME_POLICY_FILE="$PROJECT_DIR/modules/conf/themes/data/excluded.list"
export THEME_POLICY_ROOT="$SANDBOX/themes" THEME_POLICY_HOMES="$SANDBOX/homes" THEME_POLICY_ARCHIVE="$SANDBOX/archive"
source "$PROJECT_DIR/scripts/lib/theme-policy.sh"
mkdir -p "$THEME_POLICY_ROOT"/{matte-black,solitude,allowed} "$THEME_POLICY_HOMES/user/.config/os/themes/matte-black"
printf 'personal palette\n' > "$THEME_POLICY_HOMES/user/.config/os/themes/matte-black/colors.toml"
test_section "Theme exclusions"
assert_true "excluded stock and user themes are archived" 'theme_policy_apply && [[ ! -e "$THEME_POLICY_ROOT/matte-black" && ! -e "$THEME_POLICY_ROOT/solitude" && ! -e "$THEME_POLICY_HOMES/user/.config/os/themes/matte-black" ]] && grep -qx "personal palette" "$THEME_POLICY_ARCHIVE"/users/user/matte-black.*/theme/colors.toml'
assert_true "remaining themes are preserved" '[[ -d "$THEME_POLICY_ROOT/allowed" ]]'
assert_true "repeated cleanup preserves the original archives" 'theme_policy_apply && [[ $(find "$THEME_POLICY_ARCHIVE/system" -mindepth 1 -maxdepth 1 -type d | wc -l) == 2 ]]'
assert_true "an updated stock theme is removed again" 'mkdir "$THEME_POLICY_ROOT/solitude" && theme_policy_apply && [[ ! -e "$THEME_POLICY_ROOT/solitude" ]]'
assert_false "linked theme roots are rejected" 'ln -s "$THEME_POLICY_ROOT" "$SANDBOX/linked" && theme_policy_prune "$SANDBOX/linked" "$SANDBOX/other"'
printf '../outside\n' > "$SANDBOX/invalid.list"
assert_false "invalid exclusion paths cannot escape the theme root" 'THEME_POLICY_FILE="$SANDBOX/invalid.list" theme_policy_apply'
assert_false "preview installation rejects traversal before filesystem writes" 'bash "$PROJECT_DIR/modules/theme-previews/apply.sh" ../outside'
assert_file_contains_literal "capture verifies monitor dimensions before export" "$PROJECT_DIR/modules/theme-previews/rebuild-previews.sh" '== "$monitor_geometry"'
assert_file_contains_literal "capture validates window ownership" "$PROJECT_DIR/modules/theme-previews/rebuild-previews.sh" 'index($pid) != null'
assert_file_contains_literal "capture restores notification state" "$PROJECT_DIR/modules/theme-previews/rebuild-previews.sh" 'setDnd "$ORIGINAL_DND"'
test_summary
