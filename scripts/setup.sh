#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$PROJECT_DIR"
MODULES_DIR="$SCRIPT_DIR/lib/modules"
LOG="${KOS_LOG:-$PROJECT_DIR/setup.log}"

if [[ "${KOS_LOG_STDOUT:-0}" -eq 0 ]]; then
    exec > >(tee -a "$LOG") 2>&1
fi
umask 077

set -euo pipefail

source "$SCRIPT_DIR/lib/i18n.sh"
source "$SCRIPT_DIR/lib/target-user.sh"

i18n_init

SETUP_SCOPE=full
scope_specified=0
while (($#)); do
    case "$1" in
        --rebuild-previews)
            KOS_REBUILD_PREVIEWS=1
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
    full|keyboard|release|iso|migrate|kernel) ;;
    *) err "setup.invalid_args" ;;
esac
[[ ( "$SETUP_SCOPE" == full || "$SETUP_SCOPE" == migrate ) || "${KOS_REBUILD_PREVIEWS:-0}" != 1 ]] || err "setup.invalid_args"

[[ $EUID -eq 0 ]] || err "__root_required"

if [[ "$SETUP_SCOPE" == kernel ]]; then
    source "$SCRIPT_DIR/lib/kernel-build.sh"
    kos_kernel_build "$PROJECT_ROOT" "$PROJECT_ROOT/dist"
    exit 0
fi

if [[ "$SETUP_SCOPE" == release || "$SETUP_SCOPE" == iso ]]; then
    log "__stage" "96-release-iso.sh"
    # shellcheck source=lib/modules/96-release-iso.sh
    source "$MODULES_DIR/96-release-iso.sh"
    log setup.release_done
    exit 0
fi

if [[ "$SETUP_SCOPE" == keyboard ]]; then
    log "__stage" "keyboard-backlight-policy.sh"
    # shellcheck source=lib/keyboard-backlight-policy.sh
    source "$SCRIPT_DIR/lib/keyboard-backlight-policy.sh"
    log "setup.keyboard_done"
    exit 0
fi

PRIMARY_USER=${KOS_SETUP_USER:-$(target_user_resolve)} || err "__cannot_determine_user"
if [[ "$PRIMARY_USER" == root ]] || ! id "$PRIMARY_USER" >/dev/null; then
    err "__cannot_determine_user"
fi

if [[ "$SETUP_SCOPE" == migrate ]]; then
    source "$SCRIPT_DIR/lib/migration.sh"
    _legacy_desktop=$(head -n 1 "$PROJECT_ROOT/conf/kos/data/migration-packages.list")
    _legacy_automation=$(cat "$PROJECT_ROOT/conf/kos/data/legacy-automation")
    for _home in /home/*; do
        [[ -d "$_home" && ! -L "$_home" ]] || continue
        kos_migrate_preflight "$_home" "$_legacy_desktop" "$_legacy_automation" || err release.invalid
    done
    source "$SCRIPT_DIR/lib/distribution.sh"
    source "$SCRIPT_DIR/lib/kernel-build.sh"
    kos_kernel_build "$PROJECT_ROOT" "$PROJECT_ROOT/dist"
    _runtime_package=$(kos_package_build "$PROJECT_ROOT" "$PROJECT_ROOT/dist") || err release.invalid
    mapfile -t _runtime_packages < "$PROJECT_ROOT/conf/kos/data/runtime-packages.list"
    pacman -Syu --needed --noconfirm "${_runtime_packages[@]}"
    pacman -U --noconfirm "$_runtime_package" "$PROJECT_ROOT/dist/"linux-kos-*.pkg.tar.zst
fi

MODULE_FILES=(
    "$MODULES_DIR/00-env.sh"
    "$MODULES_DIR/02-kos-runtime.sh"
    "$MODULES_DIR/03-kos-migration.sh"
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
    "$MODULES_DIR/96-release-iso.sh"
)

for mod in "${MODULE_FILES[@]}"; do
    [[ -f "$mod" ]] || continue
    mod_name=$(basename "$mod")
    log "__stage" "$mod_name"
    # shellcheck disable=SC1090
    source "$mod"
done

log "__complete"
