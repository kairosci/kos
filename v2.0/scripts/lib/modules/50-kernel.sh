#!/usr/bin/env bash

set -euo pipefail

log "kernel.hardening"
"$PROJECT_ROOT/script/os-lua" apply-kernel || err "kernel.apply_failed"
