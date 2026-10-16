#!/usr/bin/env bash
set -euo pipefail
source "$PROJECT_DIR/scripts/lib/namespace-cleanup.sh"
namespace_cleanup || err "namespace.failed"
