#!/bin/bash

Os::modules::slop::scripts::debloat_slop_sh::run() {
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
MODULES_DIR="$SCRIPT_DIR/lib/modules"

log() { printf '%s\n' "$1"; }
warn() { printf '%s\n' "warning: $1"; }
err() { printf '%s\n' "error: $1"; exit 1; }

omarchy_as() {
    local user="$1"
    shift
    [[ -n "$user" ]] || { warn "omarchy_as called without user"; return 1; }
    if [[ -z "${OMARCHY_PATH:-}" ]]; then
        if [[ -f /usr/share/omarchy/default/bash/env-bootstrap ]]; then
            # shellcheck source=/dev/null
            source /usr/share/omarchy/default/bash/env-bootstrap 2>/dev/null || warn "os env-bootstrap skipped"
        fi
        OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
    fi
    local runtime="" bus="" uid=""
    uid=$(id -u "$user" 2>/dev/null || printf '')
    if [[ -n "$uid" && -d "/run/user/$uid" ]]; then
        runtime="/run/user/$uid"
        bus="unix:path=/run/user/$uid/bus"
    fi
    sudo -u "$user" env "OMARCHY_PATH=$OMARCHY_PATH" "XDG_RUNTIME_DIR=$runtime" "DBUS_SESSION_BUS_ADDRESS=$bus" omarchy "$@"
}

[[ "${1:-}" != "--yes" ]] && cat << 'PLAN' && exit 0
AI debloat (opt-in) would:
  - disable and mask omarchy-crash-watch.service for every user
  - disable the omarchy.agents shell plugin for every user
  - remove standalone AI CLI launchers (AI runs inside the terminal only)
It never touches mise-managed AI CLIs, tensaku, editors, or shell configs.
Re-run with --yes (as root) to apply.
PLAN

[[ $EUID -eq 0 ]] || err "Root required (run via sudo or pkexec)"

export OS_SLOP_DEBLOAT=1

# shellcheck source=/dev/null
source "$MODULES_DIR/40-slop.sh"

log "AI debloat applied on explicit request."

}

Os::modules::slop::scripts::debloat_slop_sh::run "$@"
