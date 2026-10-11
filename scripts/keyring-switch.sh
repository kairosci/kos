#!/usr/bin/env bash

set -euo pipefail

script_dir=$(dirname "$(readlink -f "$0")")
source "$script_dir/lib/i18n.sh"
i18n_init

backend=${1:-gnome-keyring}
case "$backend" in
    gnome-keyring) ;;
    *) err "keyring.backend_invalid" "${backend:-unset}" ;;
esac

exec pkexec env "KOS_KEYRING_BACKEND=$backend" bash "$script_dir/setup.sh"
