#!/usr/bin/env bash

set -euo pipefail

log "ssh.secure"
"$PROJECT_ROOT/script/os-lua" apply-ssh || err "ssh.apply_failed"
