#!/usr/bin/env bash

set -euo pipefail

log "firewall.configure"
"$PROJECT_DIR/script/os-lua" apply-firewall || err "firewall.apply_failed"
