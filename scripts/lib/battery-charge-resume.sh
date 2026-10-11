#!/bin/bash
set -euo pipefail

[[ "${1:-}" == post ]] || exit 0
# shellcheck source=scripts/lib/battery-driver.sh
source /usr/local/libexec/kos-battery-driver.sh
if battery_driver_needs_recovery; then
    battery_driver_recover
fi
/usr/local/libexec/kos-set-battery-charge-limit
