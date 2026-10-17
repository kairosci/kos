#!/usr/bin/env bash

set -euo pipefail

log "auth.pam"
"$PROJECT_ROOT/script/os-lua" apply-authentication || err "auth.apply_failed"
