#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$PROJECT_DIR"
MODULES_DIR="$SCRIPT_DIR/lib/modules"
LOG="${OS_LOG:-$PROJECT_DIR/setup.log}"

if [[ "${OS_LOG_STDOUT:-0}" -eq 0 ]]; then
    exec > >(tee -a "$LOG") 2>&1
fi
umask 077

set -euo pipefail

source "$SCRIPT_DIR/lib/i18n.sh"
source "$SCRIPT_DIR/lib/target-user.sh"

locale_init

SETUP_SCOPE=full
scope_specified=0
while (($#)); do
    case "$1" in
        --rebuild-previews)
            OS_REBUILD_PREVIEWS=1
            shift
            ;;
        --restore-omarchy)
            OS_RESTORE_OMARCHY=1
            shift
            ;;
        --reset-snapshots)
            OS_RESET_SNAPSHOTS=1
            shift
            ;;
        --run-migrations)
            OS_RUN_MIGRATIONS=1
            shift
            ;;
        --scope)
            [[ $# -ge 2 && $scope_specified -eq 0 ]] || err "setup.invalid_args"
            SETUP_SCOPE="$2"
            scope_specified=1
            shift 2
            ;;
        *) err "setup.invalid_args" ;;
    esac
done
case "$SETUP_SCOPE" in
    full|keyboard|security|recovery|desktop|fontconfig|branding|bootloader|session) ;;
    *) err "setup.invalid_args" ;;
esac
[[ "$SETUP_SCOPE" == full || "${OS_REBUILD_PREVIEWS:-0}" != 1 ]] || err "setup.invalid_args"
[[ "$SETUP_SCOPE" == full || "${OS_RUN_MIGRATIONS:-0}" != 1 ]] || err "setup.invalid_args"
[[ "$SETUP_SCOPE" == full || ( "${OS_RESTORE_OMARCHY:-0}" != 1 && "${OS_RESET_SNAPSHOTS:-0}" != 1 ) ]] || err "setup.invalid_args"

[[ $EUID -eq 0 ]] || err "__root_required"

source "$SCRIPT_DIR/lib/root-recovery.sh"
if [[ "$SETUP_SCOPE" == recovery || "$SETUP_SCOPE" == desktop ]]; then
    PRIMARY_USER=${OS_SETUP_USER:-$(target_user_resolve)} || err "__cannot_determine_user"
    source "$MODULES_DIR/00-env.sh" --functions-only
    if [[ "$SETUP_SCOPE" == recovery ]]; then
        root_recovery_restore || err "recovery.failed"
    else
        root_recovery_shell || err "recovery.failed"
    fi
    exit 0
fi
root_setup_persistent || err "setup.snapshot_boot"

if [[ "$SETUP_SCOPE" == fontconfig ]]; then
    PRIMARY_USER=${OS_SETUP_USER:-$(target_user_resolve)} || err "__cannot_determine_user"
    if [[ "$PRIMARY_USER" == root ]] || ! id "$PRIMARY_USER" >/dev/null; then
        err "__cannot_determine_user"
    fi
    if ! pacman -Q omarchy >/dev/null || [[ ! -d /usr/share/omarchy ]] || ! command -v omarchy >/dev/null; then
        err "setup.omarchy_required"
    fi
    source "$MODULES_DIR/00-env.sh" --functions-only
    log "__stage" "23-fontconfig.sh"
    source "$MODULES_DIR/23-fontconfig.sh"
    omarchy_as "$PRIMARY_USER" restart shell || err "recovery.failed"
    omarchy_as "$PRIMARY_USER" shell shell ping || err "recovery.failed"
    log "__complete"
    exit 0
fi

if [[ "$SETUP_SCOPE" == keyboard ]]; then
    log "__stage" "keyboard-backlight-policy.sh"
    # shellcheck source=lib/keyboard-backlight-policy.sh
    source "$SCRIPT_DIR/lib/keyboard-backlight-policy.sh"
    log "setup.keyboard_done"
    exit 0
fi

if [[ "$SETUP_SCOPE" == session ]]; then
    PRIMARY_USER=${OS_SETUP_USER:-$(target_user_resolve)} || err "__cannot_determine_user"
    source "$MODULES_DIR/00-env.sh" --functions-only
    source "$MODULES_DIR/36-os-cli.sh"
    source "$MODULES_DIR/97-session.sh"
    exit 0
fi

if [[ "$SETUP_SCOPE" == branding ]]; then
    BRAND_ICON="$PROJECT_ROOT/modules/iso/assets/kmono-cyan.png"
    [[ -s "$BRAND_ICON" && ! -L "$BRAND_ICON" ]] || err "branding.install_failed" "$BRAND_ICON"
    install -Dm644 -- "$BRAND_ICON" /usr/share/pixmaps/os.png || err "branding.install_failed" /usr/share/pixmaps/os.png
    log "branding.completed"
    exit 0
fi

if [[ "$SETUP_SCOPE" == bootloader ]]; then
    source "$MODULES_DIR/00-env.sh" --functions-only
    log "__stage" "27-bootloader.sh"
    source "$MODULES_DIR/27-bootloader.sh"
    log "__complete"
    exit 0
fi

if [[ "$SETUP_SCOPE" == security ]]; then
    source "$MODULES_DIR/00-env.sh" --functions-only
    log "__stage" "85-security-stack.sh"
    source "$MODULES_DIR/85-security-stack.sh"
    log "__stage" "94-security-audit.sh"
    source "$MODULES_DIR/94-security-audit.sh"
    log "__complete"
    exit 0
fi

PRIMARY_USER=${OS_SETUP_USER:-$(target_user_resolve)} || err "__cannot_determine_user"
if [[ "$PRIMARY_USER" == root ]] || ! id "$PRIMARY_USER" >/dev/null; then
    err "__cannot_determine_user"
fi

if ! pacman -Q omarchy >/dev/null || [[ ! -d /usr/share/omarchy ]] || ! command -v omarchy >/dev/null; then
    err "setup.omarchy_required"
fi

MODULE_FILES=(
    "$MODULES_DIR/00-env.sh"
    "$MODULES_DIR/01-os-namespace.sh"
    "$MODULES_DIR/04-omarchy-restore.sh"
    "$MODULES_DIR/05-locale.sh"
    "$MODULES_DIR/06-omarchy-migrations.sh"
    "$MODULES_DIR/10-debloat.sh"
    "$MODULES_DIR/20-defaults.sh"
    "$MODULES_DIR/22-portals.sh"
    "$MODULES_DIR/23-fontconfig.sh"
    "$MODULES_DIR/24-user-configurations.sh"
    "$MODULES_DIR/25-desktop-cleanup.sh"
    "$MODULES_DIR/27-bootloader.sh"
    "$MODULES_DIR/30-theming.sh"
    "$MODULES_DIR/32-omaqt.sh"
    "$MODULES_DIR/35-shell-plugins.sh"
    "$MODULES_DIR/36-os-cli.sh"
    "$MODULES_DIR/40-firewall.sh"
    "$MODULES_DIR/50-kernel.sh"
    "$MODULES_DIR/60-auth.sh"
    "$MODULES_DIR/62-keyring.sh"
    "$MODULES_DIR/70-ssh.sh"
    "$MODULES_DIR/80-services.sh"
    "$MODULES_DIR/81-resolver-failover.sh"
    "$MODULES_DIR/85-security-stack.sh"
    "$MODULES_DIR/89-battery-charge.sh"
    "$MODULES_DIR/90-hardware-power.sh"
    "$MODULES_DIR/91-suspend-resume.sh"
    "$MODULES_DIR/92-responsiveness.sh"
    "$MODULES_DIR/94-security-audit.sh"
    "$MODULES_DIR/95-maintenance.sh"
    "$MODULES_DIR/97-session.sh"
)

for mod in "${MODULE_FILES[@]}"; do
    [[ -f "$mod" ]] || err "setup.stage_missing" "$mod"
    mod_name=$(basename "$mod")
    log "__stage" "$mod_name"
    # shellcheck disable=SC1090
    source "$mod"
done

if [[ "${OS_RESTORE_OMARCHY:-0}" == 1 || "${OS_RESET_SNAPSHOTS:-0}" == 1 || "${OS_RUN_MIGRATIONS:-0}" == 1 ]]; then
    user_as "$PRIMARY_USER" env OMARCHY_PATH=/usr/share/omarchy Hyprland --verify-config --config "$(getent passwd "$PRIMARY_USER" | cut -d: -f6)/.config/hypr/hyprland.lua" || err "restore.failed" "$PRIMARY_USER"
    root_recovery_shell || err "recovery.failed"
fi
if [[ "${OS_RESET_SNAPSHOTS:-0}" == 1 ]]; then
    source "$SCRIPT_DIR/lib/snapshot-baseline.sh"
    snapshot_baseline_reset || err "snapshots.failed"
fi

log "__complete"
