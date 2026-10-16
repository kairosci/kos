#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

bash "$SCRIPT_DIR/run-suite-list.sh" \
    "$SCRIPT_DIR/test_syntax_integrity.sh" \
    "$SCRIPT_DIR/test_desktop_services.sh" \
    "$SCRIPT_DIR/test_lockscreen_regression.sh" \
    "$SCRIPT_DIR/test_kernel_hardening.sh" \
    "$SCRIPT_DIR/test_arch_migration.sh" \
    "$SCRIPT_DIR/../modules/os/tests/test_app_launch.sh" \
    "$SCRIPT_DIR/../modules/os/tests/test_cli_install.sh" \
    "$SCRIPT_DIR/test_auth_pam_access.sh" \
    "$SCRIPT_DIR/test_firewall_network.sh" \
    "$SCRIPT_DIR/test_resolver_failover.sh" \
    "$SCRIPT_DIR/test_debloat_theming.sh" \
    "$SCRIPT_DIR/test_security_tooling.sh" \
    "$SCRIPT_DIR/test_bootloader.sh" \
    "$SCRIPT_DIR/test_boot_menu.sh" \
    "$SCRIPT_DIR/test_ruby_catalog.sh" \
    "$SCRIPT_DIR/test_configuration_publication.sh" \
    "$SCRIPT_DIR/test_hardware_power.sh" \
    "$SCRIPT_DIR/test_modular_pipeline.sh" \
    "$SCRIPT_DIR/test_desktop_recovery.sh" \
    "$SCRIPT_DIR/test_root_recovery.sh" \
    "$SCRIPT_DIR/test_idempotency_safety.sh" \
    "$SCRIPT_DIR/test_i18n_locale.sh" \
    "$SCRIPT_DIR/test_config_validity.sh" \
    "$SCRIPT_DIR/test_desktop_defaults.sh" \
    "$SCRIPT_DIR/test_micro.sh" \
    "$SCRIPT_DIR/test_nvim.sh" \
    "$SCRIPT_DIR/test_herdr_menu.sh" \
    "$SCRIPT_DIR/test_application_policy.sh" \
    "$SCRIPT_DIR/test_easyeffects.sh" \
    "$SCRIPT_DIR/test_desktop_cleanup.sh" \
    "$SCRIPT_DIR/test_graphical_workflow.sh" \
    "$SCRIPT_DIR/test_gui_integration.sh" \
    "$SCRIPT_DIR/test_preview_layout.sh" \
    "$SCRIPT_DIR/test_theme_policy.sh" \
    "$SCRIPT_DIR/test_bluetooth_state.sh" \
    "$SCRIPT_DIR/test_power_state.sh" \
    "$SCRIPT_DIR/test_responsiveness.sh" \
    "$SCRIPT_DIR/test_test_harness.sh" \
    "$SCRIPT_DIR/test_update_hooks.sh" \
    "$SCRIPT_DIR/test_keyboard_backlight.sh" \
    "$SCRIPT_DIR/test_iso_verify.sh" \
    "$SCRIPT_DIR/test_iso_download.sh" \
    "$SCRIPT_DIR/test_session.sh" \
    "$SCRIPT_DIR/test_session_i18n.sh" \
    "$SCRIPT_DIR/test_config_rename.sh" \
    "$SCRIPT_DIR/test_hyprmod.sh" \
    "$SCRIPT_DIR/test_desktop_health.sh" \
    "$SCRIPT_DIR/test_wallpaper.sh" \
    "$SCRIPT_DIR/test_session_catalog.sh"
