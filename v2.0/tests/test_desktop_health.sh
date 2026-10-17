#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
assert_true "health stage keeps package data separate from provisioning" "grep -q 'easyeffects/data/packages.list' '$PROJECT_DIR/scripts/lib/desktop-health.sh' && grep -q 'hyprmod/data/packages.list' '$PROJECT_DIR/scripts/lib/desktop-health.sh'"
assert_true "health stage uses a full upgrade and preserves package errors" "grep -q 'pacman -Syu' '$PROJECT_DIR/scripts/lib/desktop-health.sh' && grep -q 'err.*defaults.app_failed' '$PROJECT_DIR/scripts/lib/desktop-health.sh'"
assert_true "health reconciles matching root runtime helpers before package hooks run" "awk '/97-session.sh.*files-only/{runtime=NR} /pacman -Syu/{exit !(runtime>0 && runtime<NR)}' '$PROJECT_DIR/scripts/lib/desktop-health.sh'"
assert_false "interface reconciliation never reloads the audio preset" "grep -q 'easyeffects' '$PROJECT_DIR/scripts/lib/desktop-interface.sh'"
assert_false "global palette leaves native geometry intact" "grep -qE 'border-radius|box-shadow|text-shadow|background-image|headerbar.*min-height|button.*min-height' '$PROJECT_DIR/data/component/application/gtk/palette.css.in'"
assert_true "HyprMod layout supports narrow navigation with back navigation" "grep -q 'BreakpointCondition.parse' '$PROJECT_DIR/modules/conf/hyprmod/data/interface.patch' && grep -q 'set_show_content(True)' '$PROJECT_DIR/modules/conf/hyprmod/data/interface.patch' && grep -q 'select_row(first_id)' '$PROJECT_DIR/modules/conf/hyprmod/data/interface.patch'"
assert_true "HyprMod exact patch refuses upstream source drift" "grep -q -- '--fuzz=0 --dry-run' '$PROJECT_DIR/modules/conf/hyprmod/scripts/interface.sh'"
assert_true "HyprMod keeps explicit auto save preferences" "grep -q 'dconf read /io/github/bluemancz/hyprmod/auto-save' '$PROJECT_DIR/modules/conf/hyprmod/scripts/interface.sh' && grep -q '\[\[ -z.*saved' '$PROJECT_DIR/modules/conf/hyprmod/scripts/interface.sh'"
test_summary
