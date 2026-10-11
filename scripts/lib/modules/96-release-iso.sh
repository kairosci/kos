#!/usr/bin/env bash

set -euo pipefail

[[ "${SETUP_SCOPE:-full}" == "release" || "${SETUP_SCOPE:-full}" == "iso" || "${KOS_BUILD_ISO:-0}" -eq 1 ]] || return 0

log "release.iso_start"

PROJECT_ROOT="${PROJECT_ROOT:-$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")}"
PROJECT_DIR="${PROJECT_DIR:-$PROJECT_ROOT}"

# shellcheck source=../../lib/distribution.sh
source "$PROJECT_ROOT/scripts/lib/distribution.sh"
# shellcheck source=../../lib/release.sh
source "$PROJECT_ROOT/scripts/lib/release.sh"

KOS_APPLY_PIPELINE=1 bash "$PROJECT_ROOT/scripts/build-release.sh"
log "release.iso_done"
