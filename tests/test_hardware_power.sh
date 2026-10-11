#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Hardware & Battery Power Management Policy"

POWER_MODULE="$PROJECT_DIR/scripts/lib/modules/89-battery-charge.sh"
HARDWARE_POWER_MODULE="$PROJECT_DIR/scripts/lib/modules/90-hardware-power.sh"
SUSPEND_POWER_MODULE="$PROJECT_DIR/scripts/lib/modules/91-suspend-resume.sh"
assert_file_exists "hardware power module exists" "$POWER_MODULE"
assert_file_exists "suspend power module exists" "$SUSPEND_POWER_MODULE"
assert_file_contains "power module provisions /etc/omaconf/power.conf" "$POWER_MODULE" "/etc/omaconf/power.conf"
assert_file_contains "power module sets 75% battery limit policy" "$POWER_MODULE" "BATTERY_CHARGE_LIMIT=75"
assert_file_contains "power module provisions udev battery rule" "$POWER_MODULE" "98-battery-charge-threshold.rules"
assert_file_contains "power module provisions systemd-tmpfiles rule" "$POWER_MODULE" "battery-charge-threshold.conf"
assert_file_contains "power module provisions systemd battery service" "$POWER_MODULE" "battery-charge-threshold.service"
assert_file_contains "power module provisions the resume hook" "$POWER_MODULE" "battery-charge-resume.sh"
assert_file_contains_literal "udev trigger is scoped to battery nodes" "$POWER_MODULE" "--sysname-match="
assert_true "udev trigger does not fire on the whole power_supply subsystem" \
    "! grep -qE 'udevadm trigger --subsystem-match=power_supply[[:space:]]*(2>|;|\$)' '$POWER_MODULE'"
assert_file_contains "suspend power module configures safe memory sleep mode" "$SUSPEND_POWER_MODULE" "MemorySleepMode="
assert_file_contains "suspend power module handles s2idle and deep modes" "$SUSPEND_POWER_MODULE" "target_sleep_mode="
assert_file_contains "suspend power module removes legacy deep sleep config" "$SUSPEND_POWER_MODULE" "99-omaconf-deep-sleep.conf"
assert_file_exists "battery threshold helper exists" "$PROJECT_DIR/scripts/lib/set-battery-charge-limit.sh"
assert_file_exists "battery resume helper exists" "$PROJECT_DIR/scripts/lib/battery-charge-resume.sh"
assert_file_contains "battery helper probes the threshold capability before writing" "$PROJECT_DIR/scripts/lib/set-battery-charge-limit.sh" "threshold_functional"
assert_file_contains_literal "battery helper verifies the applied limit by reading it back" "$PROJECT_DIR/scripts/lib/set-battery-charge-limit.sh" 'got=$(threshold_read "$node") || return 1'
assert_file_contains_literal "battery helper owns the enforcement state directory" "$PROJECT_DIR/scripts/lib/set-battery-charge-limit.sh" 'OMACONF_BATTERY_STATE_DIR:-/run/omaconf'
assert_file_contains_literal "battery helper records the enforcement state" "$PROJECT_DIR/scripts/lib/set-battery-charge-limit.sh" 'STATE_FILE="$STATE_DIR/battery-charge-limit.state"'
assert_file_contains "battery helper reports the firmware unsupported reason" "$PROJECT_DIR/scripts/lib/set-battery-charge-limit.sh" "reason=firmware_unsupported"
assert_file_contains_literal "battery helper exposes a query interface" "$PROJECT_DIR/scripts/lib/set-battery-charge-limit.sh" '--query|query)'
assert_file_contains "power module reports the enforced limit" "$POWER_MODULE" "power.charge_enforced"
assert_file_contains "power module reports an unsupported firmware" "$POWER_MODULE" "power.charge_unsupported"
assert_file_contains_literal "power module reads the enforcement state through the helper" "$POWER_MODULE" 'battery_query enforced'
assert_file_not_contains "power module does not duplicate the state path" "$POWER_MODULE" "/run/omaconf/battery-charge-limit.state"
assert_file_contains_literal "verify derives the battery verdict from the helper state" "$PROJECT_DIR/scripts/verify.sh" '--query state_limit'
assert_file_contains "verify skips the battery limit on unsupported firmware" "$PROJECT_DIR/scripts/verify.sh" "verify.skip_charge_unsupported"
assert_file_contains_literal "verify fails the battery limit on drift" "$PROJECT_DIR/scripts/verify.sh" 'check "$(t check.battery_limit)" false'
assert_file_not_contains "verify has no existence based battery gate" "$PROJECT_DIR/scripts/verify.sh" "ls /sys/class/power_supply/BAT\*/charge_control_end_threshold"

if [[ -f /etc/omaconf/power.conf ]]; then
    assert_file_contains "power.conf defines BATTERY_CHARGE_LIMIT" "/etc/omaconf/power.conf" "BATTERY_CHARGE_LIMIT=[0-9]+"
fi

if [[ -f /etc/udev/rules.d/98-battery-charge-threshold.rules ]]; then
    assert_file_contains "udev rule matches power_supply subsystem" "/etc/udev/rules.d/98-battery-charge-threshold.rules" "SUBSYSTEM==\"power_supply\""
    assert_file_contains "udev rule targets battery devices by type" "$POWER_MODULE" 'ATTR\{type\}=="Battery"'
    assert_file_contains "udev delegates to the verified helper" "$POWER_MODULE" 'RUN\+="/usr/local/libexec/omaconf-set-battery-charge-limit"'
fi

if [[ -f /etc/tmpfiles.d/battery-charge-threshold.conf ]]; then
    assert_file_contains "tmpfiles prepares the state directory" "$POWER_MODULE" '^d /run/omaconf 0755 root root -'
fi

if [[ -f /etc/systemd/system/battery-charge-threshold.service ]]; then
    assert_file_contains "battery service applies the shared helper" "/etc/systemd/system/battery-charge-threshold.service" "omaconf-set-battery-charge-limit"
    assert_true "battery charge threshold service is enabled" "systemctl is-enabled battery-charge-threshold.service &>/dev/null || [[ -L /etc/systemd/system/multi-user.target.wants/battery-charge-threshold.service ]]"
fi

functional_battery_node() {
    local bat_node val
    for bat_node in /sys/class/power_supply/BAT*/charge_control_end_threshold /sys/class/power_supply/BAT*/charge_stop_threshold /sys/class/power_supply/BAT*/charge_end_threshold /sys/class/power_supply/BATT*/charge_control_end_threshold; do
        [[ -f "$bat_node" ]] || continue
        val=$(cat "$bat_node" 2>/dev/null || printf '')
        [[ "$val" =~ ^[0-9]+$ ]] && return 0
    done
    return 1
}

check_live_battery_threshold() {
    local want="$1"
    local bat_node val checked=0
    for bat_node in /sys/class/power_supply/BAT*/charge_control_end_threshold /sys/class/power_supply/BAT*/charge_stop_threshold /sys/class/power_supply/BAT*/charge_end_threshold /sys/class/power_supply/BATT*/charge_control_end_threshold; do
        [[ -f "$bat_node" ]] || continue
        val=$(cat "$bat_node" 2>/dev/null || printf '')
        [[ "$val" =~ ^[0-9]+$ ]] || continue
        checked=$((checked + 1))
        [[ "$val" == "$want" ]] || return 1
    done
    [[ "$checked" -gt 0 ]]
}

power_policy_limit() {
    local val
    val=$(sed -n 's/^BATTERY_CHARGE_LIMIT=\([0-9][0-9]*\)$/\1/p' /etc/omaconf/power.conf 2>/dev/null | head -1)
    printf '%s' "${val:-75}"
}

BATTERY_HELPER=/usr/local/libexec/omaconf-set-battery-charge-limit
if [[ -x "$BATTERY_HELPER" && -r /etc/omaconf/power.conf ]]; then
    recorded_limit=$("$BATTERY_HELPER" --query state_limit 2>/dev/null || printf '')
    assert_equal "recorded battery limit matches the policy" "$recorded_limit" "$(power_policy_limit)"

    if functional_battery_node; then
        assert_true "live battery charge threshold matches the policy" "check_live_battery_threshold $(power_policy_limit)"
    else
        assert_false "live battery charge threshold must not drift once supported" "functional_battery_node && ! check_live_battery_threshold $(power_policy_limit)"
    fi
fi

battery_helper_query() {
    local want="$1" key="$2"
    OMACONF_BATTERY_STATE_DIR="$SANDBOX_STATE" \
        OMACONF_POWER_CONF="$SANDBOX_CONF" \
        OMACONF_POWER_SUPPLY_ROOT="$SANDBOX_POWER" \
        "$PROJECT_DIR/scripts/lib/set-battery-charge-limit.sh" --query "$key" 2>/dev/null | grep -qx "$want"
}

battery_helper_apply() {
    OMACONF_BATTERY_STATE_DIR="$SANDBOX_STATE" \
        OMACONF_POWER_CONF="$SANDBOX_CONF" \
        OMACONF_POWER_SUPPLY_ROOT="$SANDBOX_POWER" \
        "$PROJECT_DIR/scripts/lib/set-battery-charge-limit.sh"
}

SANDBOX=$(mktemp -d)
SANDBOX_STATE="$SANDBOX/run"
SANDBOX_CONF="$SANDBOX/power.conf"
SANDBOX_POWER="$SANDBOX/power_supply"
mkdir -p "$SANDBOX_POWER/BAT0"
trap 'rm -rf "$SANDBOX"' EXIT
printf 'BATTERY_CHARGE_LIMIT=60\n' > "$SANDBOX_CONF"
SANDBOX_THRESHOLD="$SANDBOX_POWER/BAT0/charge_control_end_threshold"

printf '80\n' > "$SANDBOX_THRESHOLD"
battery_helper_apply
assert_true "a functional interface is written and enforced" "battery_helper_query 60 state_limit && battery_helper_query yes enforced && battery_helper_query no drift"
assert_true "a functional interface is recorded in the state" "battery_helper_query applied reason && battery_helper_query 1 nodes_seen && battery_helper_query 1 nodes_written && battery_helper_query 0 nodes_refused"
assert_equal "the threshold file actually holds the policy value" "$(cat "$SANDBOX_THRESHOLD")" "60"

printf '80\n' > "$SANDBOX_THRESHOLD"
assert_true "a drifted supported interface is detected" "battery_helper_query yes drift"
assert_false "a drifted supported interface is never reported as enforced" "battery_helper_query yes enforced"

: > "$SANDBOX_THRESHOLD"
battery_helper_apply
assert_true "an inert firmware interface is reported as unsupported" "battery_helper_query no enforced && battery_helper_query 0 functional_nodes && battery_helper_query firmware_unsupported reason"
assert_true "an unsupported interface is never recorded as written" "battery_helper_query 0 nodes_seen && battery_helper_query 0 nodes_written"
assert_true "an unsupported interface is never reported as drifted" "battery_helper_query no drift"

: > "$SANDBOX_CONF"
printf '80\n' > "$SANDBOX_THRESHOLD"
battery_helper_apply
assert_true "a missing policy falls back to the default limit" "battery_helper_query 75 limit"

mkdir -p "$SANDBOX_POWER/BATT0" "$SANDBOX_POWER/vendor-battery" "$SANDBOX_POWER/adapter"
printf 'Battery\n' > "$SANDBOX_POWER/vendor-battery/type"
printf 'Mains\n' > "$SANDBOX_POWER/adapter/type"
printf '80\n' > "$SANDBOX_POWER/BATT0/charge_stop_threshold"
printf '80\n' > "$SANDBOX_POWER/vendor-battery/charge_end_threshold"
printf '80\n' > "$SANDBOX_POWER/adapter/charge_end_threshold"
battery_helper_apply
assert_true "battery enumeration counts each interface once regardless of name" "battery_helper_query 3 nodes_seen && battery_helper_query 3 nodes_written"
assert_equal "non battery supplies are preserved" "$(cat "$SANDBOX_POWER/adapter/charge_end_threshold")" "80"
rm "$SANDBOX_POWER/vendor-battery/charge_end_threshold"
ln -s /proc/self/mem "$SANDBOX_POWER/vendor-battery/charge_end_threshold"
assert_true "read errors are drift rather than unsupported firmware" "battery_helper_query yes drift && battery_helper_query no enforced"
assert_false "unreadable interfaces fail application" "battery_helper_apply"
assert_true "unreadable interfaces are recorded as rejected" "battery_helper_query partial reason && battery_helper_query 1 nodes_refused"

check_samsung_recovery() (
    local recovery_root="$SANDBOX/recovery" actions="$SANDBOX/recovery-actions"
    mkdir -p "$recovery_root/BAT1/extensions/samsung-galaxybook"
    printf '1\n' > "$recovery_root/BAT1/present"
    printf '34\n' > "$recovery_root/BAT1/capacity"
    ln -s /proc/self/mem "$recovery_root/BAT1/charge_control_end_threshold"
    ln -s /proc/self/mem "$recovery_root/BAT1/uevent"
    : > "$actions"
    # shellcheck disable=SC2329
    modprobe() {
        printf '%s\n' "$*" >> "$actions"
        if [[ "$1" == -r ]]; then
            rm "$recovery_root/BAT1/charge_control_end_threshold" "$recovery_root/BAT1/uevent"
            printf 'POWER_SUPPLY_TYPE=Battery\n' > "$recovery_root/BAT1/uevent"
        fi
    }
    export OMACONF_POWER_SUPPLY_ROOT="$recovery_root"
    source "$PROJECT_DIR/scripts/lib/battery-driver.sh"
    battery_driver_needs_recovery && battery_driver_recover
    [[ $(cat "$actions") == $'-r samsung_galaxybook\nsamsung_galaxybook' ]] || return 1
    : > "$actions"
    ! battery_driver_needs_recovery && [[ ! -s "$actions" ]]
)
assert_true "Samsung recovery restores events and leaves a recovered driver alone" "check_samsung_recovery"

test_summary
