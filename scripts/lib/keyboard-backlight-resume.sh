#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == post ]] || exit 0
/usr/local/libexec/kos-keyboard-backlight
