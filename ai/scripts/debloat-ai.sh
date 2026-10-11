#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
MODULES_DIR="$SCRIPT_DIR/lib/modules"

log() { printf '%s\n' "$1"; }
warn() { printf '%s\n' "warning: $1"; }
err() { printf '%s\n' "error: $1"; exit 1; }

kos_as() {
    local user="$1"
    shift
    [[ -n "$user" ]] || { warn "kos_as called without user"; return 1; }
    if [[ -z "${KOS_PATH:-}" ]]; then
        if [[ -f /usr/share/kos/default/bash/env-bootstrap ]]; then
            # shellcheck source=/dev/null
            source /usr/share/kos/default/bash/env-bootstrap 2>/dev/null || warn "kos env-bootstrap skipped"
        fi
        KOS_PATH="${KOS_PATH:-/usr/share/kos}"
    fi
    local runtime="" bus="" uid=""
    uid=$(id -u "$user" 2>/dev/null || printf '')
    if [[ -n "$uid" && -d "/run/user/$uid" ]]; then
        runtime="/run/user/$uid"
        bus="unix:path=/run/user/$uid/bus"
    fi
    sudo -u "$user" env "KOS_PATH=$KOS_PATH" "XDG_RUNTIME_DIR=$runtime" "DBUS_SESSION_BUS_ADDRESS=$bus" kos "$@"
}

[[ "${1:-}" != "--yes" ]] && cat << 'PLAN' && exit 0
AI debloat (opt-in) would:
  - disable and mask kos-crash-watch.service for every user
  - disable the kos.agents shell plugin for every user
  - remove standalone AI CLI launchers (AI runs inside the terminal only)
It never touches mise-managed AI CLIs, tensaku, editors, or shell configs.
Re-run with --yes (as root) to apply.
PLAN

[[ $EUID -eq 0 ]] || err "Root required (run via sudo or pkexec)"

export KOS_AI_DEBLOAT=1

# shellcheck source=/dev/null
source "$MODULES_DIR/40-ai.sh"

log "AI debloat applied on explicit request."
