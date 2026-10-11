#!/usr/bin/env bash
set -euo pipefail

source "$PROJECT_DIR/scripts/lib/os-identity.sh"
log "identity.kos"
kos_identity_apply "" "$(cat "$PROJECT_DIR/conf/kos/data/version")" || err "identity.failed"
install -D -m 644 "$PROJECT_DIR/scripts/lib/os-identity.sh" /usr/local/lib/kos/os-identity.sh
