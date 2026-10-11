#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$PROJECT_DIR")"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Hardware & Battery Power Management Policy"

POWER_MODULE="$PROJECT_ROOT/scripts/lib/modules/89-battery-charge.sh"
UPower_MODULE="$PROJECT_DIR/scripts/lib/modules/10-power.sh"
assert_file_exists "power module exists" "$POWER_MODULE"
assert_file_contains "power module provisions /etc/omaconf/power.conf" "$POWER_MODULE" "/etc/omaconf/power.conf"
assert_file_contains "power module sets 75% battery limit policy" "$POWER_MODULE" "BATTERY_CHARGE_LIMIT=75"
assert_file_contains "power module provisions udev battery rule" "$POWER_MODULE" "98-battery-charge-threshold.rules"
assert_file_contains "power module provisions systemd-tmpfiles rule" "$POWER_MODULE" "battery-charge-threshold.conf"
assert_file_contains "power module provisions systemd battery service" "$POWER_MODULE" "battery-charge-threshold.service"
assert_file_contains "power module provisions UPower low-battery policy" "$UPower_MODULE" "99-omaconf-low-battery.conf"
assert_file_contains "power module hibernates at critical battery level" "$UPower_MODULE" "CriticalPowerAction=Hibernate"
assert_file_contains "power module warns at 20 percent battery" "$UPower_MODULE" "PercentageLow=20"

if [[ -f /etc/omaconf/power.conf ]]; then
    assert_file_contains "power.conf defines BATTERY_CHARGE_LIMIT" "/etc/omaconf/power.conf" "BATTERY_CHARGE_LIMIT=[0-9]+"
fi

if [[ -f /etc/udev/rules.d/98-battery-charge-threshold.rules ]]; then
    assert_file_contains "udev rule matches power_supply subsystem" "/etc/udev/rules.d/98-battery-charge-threshold.rules" "SUBSYSTEM==\"power_supply\""
    assert_file_contains "udev rule targets battery devices by type" "/etc/udev/rules.d/98-battery-charge-threshold.rules" 'ATTR\{type\}=="Battery"'
    assert_file_contains "udev rule delegates to the verified helper" "/etc/udev/rules.d/98-battery-charge-threshold.rules" 'RUN\+="/usr/local/libexec/omaconf-set-battery-charge-limit"'
fi

if [[ -f /etc/tmpfiles.d/battery-charge-threshold.conf ]]; then
    assert_file_contains "tmpfiles prepares the state directory" "/etc/tmpfiles.d/battery-charge-threshold.conf" '^d /run/omaconf 0755 root root -'
fi

if [[ -f /etc/systemd/system/battery-charge-threshold.service ]]; then
    assert_file_contains "battery service applies shared helper" "/etc/systemd/system/battery-charge-threshold.service" "omaconf-set-battery-charge-limit"
    assert_true "battery charge threshold service is enabled" "systemctl is-enabled battery-charge-threshold.service &>/dev/null || [[ -L /etc/systemd/system/multi-user.target.wants/battery-charge-threshold.service ]]"
fi

if [[ -f /etc/UPower/UPower.conf.d/99-omaconf-low-battery.conf ]]; then
    assert_file_contains "UPower drop-in hibernates at critical level" "/etc/UPower/UPower.conf.d/99-omaconf-low-battery.conf" "CriticalPowerAction=Hibernate"
    assert_file_contains "UPower drop-in acts at 5 percent" "/etc/UPower/UPower.conf.d/99-omaconf-low-battery.conf" "PercentageAction=5"
fi

BATTERY_HELPER=/usr/local/libexec/omaconf-set-battery-charge-limit
if [[ -x "$BATTERY_HELPER" && -r /etc/omaconf/power.conf ]]; then
    assert_true "recorded battery charge limit matches policy" "[[ \"\$('$BATTERY_HELPER' --query state_limit)\" == \"\$('$BATTERY_HELPER' --query limit)\" ]]"
    functional_nodes=$("$BATTERY_HELPER" --query functional_nodes)
    if [[ "$functional_nodes" == 0 ]]; then
        assert_true "unsupported firmware is not reported as enforced" "[[ \"\$('$BATTERY_HELPER' --query enforced)\" == no ]]"
    else
        assert_true "supported battery threshold does not drift" "[[ \"\$('$BATTERY_HELPER' --query drift)\" == no ]]"
    fi
fi

test_summary
