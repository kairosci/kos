#!/usr/bin/env bash
set -euo pipefail
log distribution.start
pacman -Q kos >/dev/null || err distribution.required
