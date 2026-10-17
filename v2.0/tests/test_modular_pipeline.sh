#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MODULES_DIR="$PROJECT_DIR/scripts/lib/modules"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Modular Pipeline Architecture & Integrity"

EXPECTED_MODULES=(
    "00-env.sh"
    "01-os-namespace.sh"
    "04-omarchy-restore.sh"
    "05-locale.sh"
    "06-omarchy-migrations.sh"
    "10-debloat.sh"
    "20-defaults.sh"
    "22-portals.sh"
    "23-fontconfig.sh"
    "25-desktop-cleanup.sh"
    "27-bootloader.sh"
    "30-theming.sh"
    "32-omaqt.sh"
    "35-shell-plugins.sh"
    "36-os-cli.sh"
    "40-firewall.sh"
    "50-kernel.sh"
    "60-auth.sh"
    "62-keyring.sh"
    "70-ssh.sh"
    "80-services.sh"
    "81-resolver-failover.sh"
    "85-security-stack.sh"
    "89-battery-charge.sh"
    "90-hardware-power.sh"
    "91-suspend-resume.sh"
    "92-responsiveness.sh"
    "94-security-audit.sh"
    "95-maintenance.sh"
    "97-session.sh"
)

for m in "${EXPECTED_MODULES[@]}"; do
    mpath="$MODULES_DIR/$m"
    assert_file_exists "module $m exists" "$mpath"
    assert_file_executable "module $m is executable" "$mpath"
    assert_file_contains "module $m has strict mode" "$mpath" "set -euo pipefail"
    assert_file_contains "setup.sh references module $m" "$PROJECT_DIR/scripts/setup.sh" "$m"
done


assert_file_contains "00-env defines aur_verified_install" "$MODULES_DIR/00-env.sh" "aur_verified_install\(\)"
assert_file_contains "AUR install delegates to the Lua component" "$MODULES_DIR/00-env.sh" 'install-aur.*PRIMARY_USER'
assert_file_contains "00-env defines omarchy_as helper" "$MODULES_DIR/00-env.sh" "omarchy_as\(\)"
assert_file_contains "omarchy_as forwards the user session bus" "$MODULES_DIR/00-env.sh" "DBUS_SESSION_BUS_ADDRESS"
assert_file_contains "20-defaults routes the browser through omarchy_as" "$MODULES_DIR/20-defaults.sh" "omarchy_as"
assert_file_contains "35-shell-plugins refreshes the local plugin catalog" "$MODULES_DIR/35-shell-plugins.sh" 'shell shell rescanPlugins'
assert_file_not_contains "35-shell-plugins has no inaccessible default repository" "$MODULES_DIR/35-shell-plugins.sh" 'https://github.com/omamodules/conf/omamp.git'
assert_file_contains "35-shell-plugins routes through omarchy_as" "$MODULES_DIR/35-shell-plugins.sh" "omarchy_as"
assert_file_contains "32-omaqt tracks the omaqt checkout" "$MODULES_DIR/32-omaqt.sh" "OMAQT_DIR"
assert_file_contains "10-debloat delegates package reconciliation to Lua" "$MODULES_DIR/10-debloat.sh" "apply-debloat"
assert_file_contains "85-security-stack defines SECURITY_PKGS array" "$MODULES_DIR/85-security-stack.sh" "SECURITY_PKGS=\("
assert_file_contains "setup.sh checks EUID root requirement" "$PROJECT_DIR/scripts/setup.sh" "EUID -eq 0"
assert_file_contains "security scope reconciles security and audit stages" "$PROJECT_DIR/scripts/setup.sh" 'SETUP_SCOPE.*security'

for scope in migrate release iso kernel; do
    assert_false "setup rejects retired $scope scope" "OS_LOG_STDOUT=1 bash '$PROJECT_DIR/scripts/setup.sh' --scope '$scope'"
done
assert_file_contains_literal "setup requires the installed Omarchy runtime" "$PROJECT_DIR/scripts/setup.sh" 'pacman -Q omarchy'
assert_file_not_contains "setup preserves the upstream system identity" "$PROJECT_DIR/scripts/setup.sh" 'os-identity'

test_summary
