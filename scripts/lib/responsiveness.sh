#!/usr/bin/env bash

responsiveness_user_systemctl() {
    local uid
    if [[ $EUID -eq 0 && -n ${TARGET_USER:-} ]]; then
        uid=$(id -u "$TARGET_USER") || return 1
        runuser -u "$TARGET_USER" -- env "XDG_RUNTIME_DIR=/run/user/$uid" \
            "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus" systemctl --user "$@"
    else
        systemctl --user "$@"
    fi
}

responsiveness_files_match() {
    local root="$1" slice
    cmp -s "$root/conf/performance/data/oomd.conf" /etc/systemd/oomd.conf.d/90-os.conf || return 1
    for slice in app background session; do
        cmp -s "$root/conf/performance/data/$slice.slice.conf" "/etc/systemd/user/$slice.slice.d/90-os.conf" || return 1
    done
    for slice in user user-; do
        cmp -s "$root/conf/performance/data/memory.slice.conf" "/etc/systemd/system/$slice.slice.d/90-os-memory.conf" || return 1
    done
    cmp -s "$root/conf/performance/data/memory.slice.conf" /etc/systemd/user/session.slice.d/90-os-memory.conf || return 1
    cmp -s <(sed 's/^\[Slice\]$/[Service]/' "$root/conf/performance/data/memory.slice.conf") /etc/systemd/system/user@.service.d/90-os-memory.conf || return 1
}

responsiveness_runtime() {
    local root="$1" slice value report limit duration swap uid expected_limit
    systemctl is-enabled --quiet systemd-oomd.service || return 1
    systemctl is-active --quiet systemd-oomd.service || return 1
    limit=$(sed -n 's/^DefaultMemoryPressureLimit=//p' "$root/conf/performance/data/oomd.conf") || return 1
    duration=$(sed -n 's/^DefaultMemoryPressureDurationSec=//p' "$root/conf/performance/data/oomd.conf") || return 1
    swap=$(sed -n 's/^SwapUsedLimit=//p' "$root/conf/performance/data/oomd.conf") || return 1
    expected_limit=$(( ${limit%%%} * 4294967295 / 100 ))
    report=$(LC_ALL=C oomctl --no-pager) || return 1
    grep -qxF "Swap Used Limit: ${swap%%%}.00%" <<< "$report" || return 1
    grep -qxF "Default Memory Pressure Limit: ${limit%%%}.00%" <<< "$report" || return 1
    grep -qxF "Default Memory Pressure Duration: $duration" <<< "$report" || return 1
    for slice in app background; do
        value=$(responsiveness_user_systemctl show "$slice.slice" -p ManagedOOMMemoryPressure --value) || return 1
        [[ "$value" == kill ]] || return 1
        value=$(responsiveness_user_systemctl show "$slice.slice" -p ManagedOOMSwap --value) || return 1
        [[ "$value" == kill ]] || return 1
        value=$(responsiveness_user_systemctl show "$slice.slice" -p ManagedOOMMemoryPressureLimit --value) || return 1
        [[ "$value" == "$expected_limit" ]] || return 1
    done
    value=$(responsiveness_user_systemctl show session.slice -p CPUWeight --value) || return 1
    [[ "$value" == 200 ]] || return 1
    value=$(responsiveness_user_systemctl show session.slice -p IOWeight --value) || return 1
    [[ "$value" == 200 ]] || return 1
    value=$(responsiveness_user_systemctl show session.slice -p MemoryLow --value) || return 1
    [[ "$value" == 536870912 ]] || return 1
    uid="${TARGET_UID:-}"
    [[ -n "$uid" ]] || uid=$(id -u) || return 1
    for slice in user.slice "user-$uid.slice" "user@$uid.service"; do
        value=$(systemctl show "$slice" -p MemoryLow --value) || return 1
        [[ "$value" == 536870912 ]] || return 1
    done
    value=$(responsiveness_user_systemctl show session.slice -p ManagedOOMMemoryPressure --value) || return 1
    [[ "$value" == auto ]] || return 1
    value=$(responsiveness_user_systemctl show session.slice -p ManagedOOMSwap --value) || return 1
    [[ "$value" == auto ]] || return 1
}
