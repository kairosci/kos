#!/usr/bin/env bash

battery_driver_needs_recovery() {
    local battery
    for battery in "${OMACONF_POWER_SUPPLY_ROOT:-/sys/class/power_supply}"/*; do
        [[ -d "$battery/extensions/samsung-galaxybook" ]] || continue
        if [[ -r "$battery/present" ]] && [[ $(cat "$battery/present") == 1 ]] &&
            cat "$battery/capacity" >/dev/null &&
            ! cat "$battery/charge_control_end_threshold" >/dev/null 2>&1 &&
            ! grep -q '^POWER_SUPPLY_TYPE=Battery$' "$battery/uevent"; then
            return 0
        fi
    done
    return 1
}

battery_driver_recover() {
    modprobe -r samsung_galaxybook && modprobe samsung_galaxybook
}
