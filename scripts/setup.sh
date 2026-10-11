#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$PROJECT_DIR"
MODULES_DIR="$SCRIPT_DIR/lib/modules"
LOG="${OMACONF_LOG:-$PROJECT_DIR/setup.log}"

if [[ "${OMACONF_LOG_STDOUT:-0}" -eq 0 ]]; then
    exec > >(tee -a "$LOG") 2>&1
fi
umask 077

set -euo pipefail

source "$SCRIPT_DIR/lib/i18n.sh"
source "$SCRIPT_DIR/lib/target-user.sh"

i18n_init

if [[ "${1:-}" == --rebuild-previews ]]; then
    OMACONF_REBUILD_PREVIEWS=1
    shift
fi
(($# == 0)) || err "setup.invalid_args"

[[ $EUID -eq 0 ]] || err "__root_required"

PRIMARY_USER=$(target_user_resolve) || err "__cannot_determine_user"

MODULE_FILES=(
    "$MODULES_DIR/00-env.sh"
    "$MODULES_DIR/05-locale.sh"
    "$MODULES_DIR/06-os-identity.sh"
    "$MODULES_DIR/10-debloat.sh"
    "$MODULES_DIR/20-defaults.sh"
    "$MODULES_DIR/22-portals.sh"
    "$MODULES_DIR/24-user-configurations.sh"
    "$MODULES_DIR/25-desktop-cleanup.sh"
    "$MODULES_DIR/30-theming.sh"
    "$MODULES_DIR/32-omaqt.sh"
    "$MODULES_DIR/35-shell-plugins.sh"
    "$MODULES_DIR/40-firewall.sh"
    "$MODULES_DIR/50-kernel.sh"
    "$MODULES_DIR/60-auth.sh"
    "$MODULES_DIR/62-keyring.sh"
    "$MODULES_DIR/70-ssh.sh"
    "$MODULES_DIR/80-services.sh"
    "$MODULES_DIR/85-security-stack.sh"
    "$MODULES_DIR/89-battery-charge.sh"
    "$MODULES_DIR/90-hardware-power.sh"
    "$MODULES_DIR/91-suspend-resume.sh"
    "$MODULES_DIR/92-responsiveness.sh"
    "$MODULES_DIR/95-maintenance.sh"
)

for mod in "${MODULE_FILES[@]}"; do
    [[ -f "$mod" ]] || continue
    mod_name=$(basename "$mod")
    log "__stage" "$mod_name"
    # shellcheck disable=SC1090
    source "$mod"
done

log "__complete"
