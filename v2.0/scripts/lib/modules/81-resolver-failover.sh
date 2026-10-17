#!/usr/bin/env bash
set -euo pipefail

log "services.resolver_failover"
"$PROJECT_DIR/script/os-lua" apply-resolver-failover || err "services.resolver_failover_failed"
