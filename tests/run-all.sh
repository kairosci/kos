#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

bash "$SCRIPT_DIR/run-suite-list.sh" \
    "$SCRIPT_DIR/test_syntax_integrity.sh" \
    "$SCRIPT_DIR/test_desktop_services.sh" \
    "$SCRIPT_DIR/test_lockscreen_regression.sh" \
    "$SCRIPT_DIR/test_kernel_hardening.sh" \
    "$SCRIPT_DIR/test_auth_pam_access.sh" \
    "$SCRIPT_DIR/test_firewall_network.sh" \
    "$SCRIPT_DIR/test_debloat_theming.sh" \
    "$SCRIPT_DIR/test_security_tooling.sh" \
    "$SCRIPT_DIR/test_hardware_power.sh" \
    "$SCRIPT_DIR/test_modular_pipeline.sh" \
    "$SCRIPT_DIR/test_idempotency_safety.sh" \
    "$SCRIPT_DIR/test_i18n_locale.sh" \
    "$SCRIPT_DIR/test_config_validity.sh" \
    "$SCRIPT_DIR/test_desktop_defaults.sh" \
    "$SCRIPT_DIR/test_herdr_menu.sh" \
    "$SCRIPT_DIR/test_application_policy.sh" \
    "$SCRIPT_DIR/test_desktop_cleanup.sh" \
    "$SCRIPT_DIR/test_graphical_workflow.sh" \
    "$SCRIPT_DIR/test_gui_integration.sh" \
    "$SCRIPT_DIR/test_preview_layout.sh" \
    "$SCRIPT_DIR/test_os_identity.sh" \
    "$SCRIPT_DIR/test_bluetooth_state.sh" \
    "$SCRIPT_DIR/test_power_state.sh" \
    "$SCRIPT_DIR/test_responsiveness.sh" \
    "$SCRIPT_DIR/test_test_harness.sh" \
    "$SCRIPT_DIR/test_update_hooks.sh"
