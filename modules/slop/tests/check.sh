#!/bin/bash

Os::modules::slop::tests::check_sh::run() {
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf '%s\n' "  pass $1"; }
bad() { FAIL=$((FAIL + 1)); printf '%s\n' "  fail $1"; }

contains() { grep -qE "$2" "$1" 2>/dev/null; }

printf '%s\n' "[slop integrity]"

if [[ -f "$PROJECT_DIR/scripts/debloat-slop.sh" ]]; then ok "entry exists"; else bad "entry exists"; fi
if [[ -x "$PROJECT_DIR/scripts/debloat-slop.sh" ]]; then ok "entry executable"; else bad "entry executable"; fi
if [[ -f "$PROJECT_DIR/scripts/lib/modules/40-slop.sh" ]]; then ok "module exists"; else bad "module exists"; fi
if [[ -x "$PROJECT_DIR/scripts/lib/modules/40-slop.sh" ]]; then ok "module executable"; else bad "module executable"; fi

if contains "$PROJECT_DIR/scripts/lib/modules/40-slop.sh" "OS_SLOP_DEBLOAT"; then ok "module gated by env flag"; else bad "module gated by env flag"; fi
if contains "$PROJECT_DIR/scripts/lib/modules/40-slop.sh" "omarchy-crash-watch"; then ok "module handles crash-watch"; else bad "module handles crash-watch"; fi
if contains "$PROJECT_DIR/scripts/lib/modules/40-slop.sh" "omarchy.agents"; then ok "module handles agents plugin"; else bad "module handles agents plugin"; fi
if contains "$PROJECT_DIR/scripts/lib/modules/40-slop.sh" "AI_LAUNCHERS"; then ok "module removes AI launchers"; else bad "module removes AI launchers"; fi
if contains "$PROJECT_DIR/scripts/lib/modules/40-slop.sh" "opencode"; then ok "module covers opencode"; else bad "module covers opencode"; fi
if contains "$PROJECT_DIR/README.md" "inside the terminal"; then ok "readme states terminal-only policy"; else bad "readme states terminal-only policy"; fi
if contains "$PROJECT_DIR/scripts/debloat-slop.sh" "yes.*to apply"; then ok "entry requires explicit yes"; else bad "entry requires explicit yes"; fi
if contains "$PROJECT_DIR/scripts/debloat-slop.sh" "omarchy_as\(\)"; then ok "entry defines omarchy_as"; else bad "entry defines omarchy_as"; fi

if bash -n "$PROJECT_DIR/scripts/debloat-slop.sh"; then ok "entry syntax valid"; else bad "entry syntax valid"; fi
if bash -n "$PROJECT_DIR/scripts/lib/modules/40-slop.sh"; then ok "module syntax valid"; else bad "module syntax valid"; fi

if "$PROJECT_DIR/scripts/debloat-slop.sh" 2>/dev/null | grep -q "opt-in"; then ok "plan mode prints scope"; else bad "plan mode prints scope"; fi

printf '%s\n' "Tests Executed: $((PASS + FAIL)) | Passed: $PASS | Failed: $FAIL"
[[ $FAIL -eq 0 ]]

}

Os::modules::slop::tests::check_sh::run "$@"
