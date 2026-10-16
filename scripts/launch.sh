#!/usr/bin/env bash

Os::scripts::launch_sh::run() {

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

source "$SCRIPT_DIR/lib/i18n.sh"

i18n_init

pkexec bash "$SCRIPT_DIR/setup.sh"
read -r -p "$(t __press_enter)"

}

Os::scripts::launch_sh::run "$@"
