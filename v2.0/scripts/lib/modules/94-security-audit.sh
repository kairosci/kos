#!/usr/bin/env bash

set -euo pipefail

log "maint.weekly"
"$PROJECT_DIR/script/os-lua" apply-security-audit || err "security.audit_apply_failed"
