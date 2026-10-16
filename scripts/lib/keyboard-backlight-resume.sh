#!/usr/bin/env bash

Os::scripts::lib::keyboard_backlight_resume_sh::run() {
set -euo pipefail
[[ "${1:-}" == post ]] || exit 0
/usr/local/libexec/os-keyboard-backlight

}

Os::scripts::lib::keyboard_backlight_resume_sh::run "$@"
