#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
source "$PROJECT_ROOT/scripts/lib/i18n.sh"
locale_init

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
    local desc="$1" condition="$2"
    if eval "$condition" &>/dev/null; then
        PASS=$((PASS + 1))
        printf '%b\n' "  ${GREEN}pass${NC} $desc"
    else
        FAIL=$((FAIL + 1))
        printf '%b\n' "  ${RED}fail${NC} $desc"
    fi
}

section() { printf '%b\n' "\n${BOLD}$1${NC}"; }

section "Battery Charge Threshold"
check "power.conf policy exists" "[[ -f /etc/os/power.conf ]]"
check "power.conf defines charge limit" "grep -q 'BATTERY_CHARGE_LIMIT=75' /etc/os/power.conf 2>/dev/null"
check "battery charge udev rule exists" "[[ -f /etc/udev/rules.d/98-battery-charge-threshold.rules ]]"
check "battery charge tmpfiles exists" "[[ -f /etc/tmpfiles.d/battery-charge-threshold.conf ]]"
check "battery service enabled" "systemctl is-enabled battery-charge-threshold.service &>/dev/null || [[ -L /etc/systemd/system/multi-user.target.wants/battery-charge-threshold.service ]]"
BATTERY_HELPER=/usr/local/libexec/os-set-battery-charge-limit
if [[ -x "$BATTERY_HELPER" ]]; then
    check "$(t check.battery_policy_applied)" "[[ \"\$('$BATTERY_HELPER' --query state_limit)\" == \"\$('$BATTERY_HELPER' --query limit)\" ]]"
    functional_nodes=$("$BATTERY_HELPER" --query functional_nodes) || exit 1
    if [[ "$functional_nodes" == 0 ]]; then
        printf '%s\n' "$(t verify.skip_charge_unsupported)"
    else
        check "$(t check.battery_limit)" "[[ \"\$('$BATTERY_HELPER' --query drift)\" == no ]]"
    fi
fi

section "Low-Battery Session Protection"
check "low-battery hibernate policy exists" "[[ -f /etc/UPower/UPower.conf.d/99-os-low-battery.conf ]]"
check "low-battery action is hibernate" "grep -q '^CriticalPowerAction=Hibernate' /etc/UPower/UPower.conf.d/99-os-low-battery.conf 2>/dev/null"
check "low-battery warning at 20 percent" "grep -q '^PercentageLow=20' /etc/UPower/UPower.conf.d/99-os-low-battery.conf 2>/dev/null"
check "low-battery critical at 10 percent" "grep -q '^PercentageCritical=10' /etc/UPower/UPower.conf.d/99-os-low-battery.conf 2>/dev/null"
check "hibernate action at 5 percent" "grep -q '^PercentageAction=5' /etc/UPower/UPower.conf.d/99-os-low-battery.conf 2>/dev/null"

section "Runtime Performance"
check "perf sysctl persisted" "[[ -f /etc/sysctl.d/99-perf.conf ]]"
check "NMI watchdog disabled live" "[[ \"\$(cat /proc/sys/kernel/nmi_watchdog 2>/dev/null)\" == 0 ]]"
check "fstrim timer enabled" "systemctl is-enabled fstrim.timer &>/dev/null"

section "AUR integrity"
check "no unverified AUR" "! grep -q 'aur_install ' '$SCRIPT_DIR/setup.sh'"
check "no yay fallback"   "! grep -q 'yay -S' '$SCRIPT_DIR/setup.sh'"

printf '\n'
printf '%b\n' "${BOLD}Passed: $PASS  Failed: $FAIL${NC}"
[[ $FAIL -eq 0 ]] || exit 1
