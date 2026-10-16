#!/usr/bin/env bash

Os::scripts::keyring_switch_sh::run() {

set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
source "$script_dir/lib/i18n.sh"
i18n_init

backend=${1:-gnome-keyring}
case "$backend" in
    gnome-keyring) ;;
    *) err "keyring.backend_invalid" "${backend:-unset}" ;;
esac

exec pkexec env "OS_KEYRING_BACKEND=$backend" bash "$script_dir/setup.sh"

}

Os::scripts::keyring_switch_sh::run "$@"
