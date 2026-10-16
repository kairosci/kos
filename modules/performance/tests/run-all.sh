#!/bin/bash

Os::modules::performance::tests::run_all_sh::run() {

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

bash "$PROJECT_ROOT/tests/run-suite-list.sh" \
    "$SCRIPT_DIR/test_syntax_integrity.sh" \
    "$SCRIPT_DIR/test_power_policy.sh" \
    "$SCRIPT_DIR/test_performance_tuning.sh" \
    "$SCRIPT_DIR/test_modular_pipeline.sh" \
    "$SCRIPT_DIR/test_idempotency_safety.sh"

}

Os::modules::performance::tests::run_all_sh::run "$@"
