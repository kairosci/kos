#!/usr/bin/env bash

set -euo pipefail

log "services.journald_harden"
"$PROJECT_DIR/script/os-lua" apply-services || err "services.apply_failed"
