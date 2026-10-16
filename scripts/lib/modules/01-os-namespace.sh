#!/usr/bin/env bash

Os::scripts::lib::modules::01_os_namespace_sh::run() {
set -euo pipefail
source "$PROJECT_DIR/scripts/lib/namespace-cleanup.sh"
namespace_cleanup || err "namespace.failed"

}

Os::scripts::lib::modules::01_os_namespace_sh::run "$@"
