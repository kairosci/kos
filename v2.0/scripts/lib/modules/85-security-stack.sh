#!/usr/bin/env bash

set -euo pipefail

log "security.install"
"$PROJECT_DIR/script/os-lua" apply-security-stack || err "security.apply_failed"
