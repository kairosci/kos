#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

bash "$PROJECT_ROOT/tests/run-suite-list.sh" \
    "$SCRIPT_DIR/test_syntax_integrity.sh" \
    "$SCRIPT_DIR/test_system_cleanup.sh" \
    "$SCRIPT_DIR/test_home_cleanup.sh" \
    "$SCRIPT_DIR/test_modular_pipeline.sh" \
    "$SCRIPT_DIR/test_idempotency_safety.sh"
