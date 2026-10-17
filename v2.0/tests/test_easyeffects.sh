#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
POLICY="$PROJECT_DIR/data/component/application/policy.json"
COMPONENT="$PROJECT_DIR/src/component/application/easyeffects.lua"
PRESET="$PROJECT_DIR/modules/conf/easyeffects/data/OS-Subwoofer.json"

test_section "EasyEffects Lua Integration"
assert_true "Lua application tests cover EasyEffects provisioning" "grep -q 'EasyEffects publishes its preset' '$PROJECT_DIR/tests/lua/run.lua'"
assert_true "EasyEffects is registered as a Lua audio component" "jq -e '.easyeffects.kind == \"audio-preset\"' '$POLICY'"
assert_true "component validates and publishes preset policy" "luac -p '$COMPONENT' && jq -e '.output.plugins_order[-1] == \"limiter#0\" and .output[\"filter#0\"][\"input-gain\"] <= -6 and .output[\"limiter#0\"].bypass == false and .output[\"limiter#0\"][\"threshold\"] <= -2 and .output[\"limiter#0\"][\"gain-boost\"] == true and .output[\"limiter#0\"].alr == false and .output[\"limiter#0\"][\"sidechain-type\"] == \"Internal\" and .output[\"filter#0\"].type == \"High-pass\" and .output[\"filter#0\"].frequency >= 60 and .output[\"bass_enhancer#0\"][\"floor-active\"] == true' '$PRESET'"
assert_true "EasyEffects Bash installer and activator were retired" "[[ ! -e '$PROJECT_DIR/modules/conf/easyeffects/install.sh' && ! -e '$PROJECT_DIR/modules/conf/easyeffects/apply.sh' ]]"
assert_true "dedicated scope applies through the setup pipeline" "grep -q 'SCOPE=easyeffects' '$PROJECT_DIR/Makefile' && grep -q 'SETUP_SCOPE.*easyeffects' '$PROJECT_DIR/scripts/setup.sh'"
assert_true "all public EasyEffects guides describe Lua setup" "grep -q 'SCOPE=easyeffects' '$PROJECT_DIR/docs/it/modules/conf/easyeffects/README.md' && grep -q 'SCOPE=easyeffects' '$PROJECT_DIR/docs/en/modules/conf/easyeffects/README.md' && grep -q 'SCOPE=easyeffects' '$PROJECT_DIR/docs/fr/modules/conf/easyeffects/README.md'"
test_summary
