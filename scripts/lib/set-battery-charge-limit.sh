#!/bin/bash
set -euo pipefail

STATE_DIR="${OMACONF_BATTERY_STATE_DIR:-/run/omaconf}"
STATE_FILE="$STATE_DIR/battery-charge-limit.state"
CONFIG="${OMACONF_POWER_CONF:-/etc/omaconf/power.conf}"
POWER_SUPPLY_ROOT="${OMACONF_POWER_SUPPLY_ROOT:-/sys/class/power_supply}"
DEFAULT_LIMIT=75
ATTRIBUTES=(charge_control_end_threshold charge_stop_threshold charge_end_threshold)

usage() {
    printf 'usage: %s [--apply | --query <key>]\n' "${0##*/}"
}

resolve_limit() {
    local configured=""
    if [[ -r "$CONFIG" ]]; then
        configured=$(sed -n 's/^BATTERY_CHARGE_LIMIT=\([0-9][0-9]*\)$/\1/p' "$CONFIG" | head -n 1)
    fi
    if [[ "$configured" =~ ^([5-9][0-9]|100)$ ]]; then
        printf '%s\n' "$configured"
        return 0
    fi
    printf '%s\n' "$DEFAULT_LIMIT"
}

threshold_read() {
    local node="$1" value=""
    [[ -r "$node" ]] || return 1
    value=$(cat "$node" 2>/dev/null) || return 1
    [[ "$value" =~ ^[0-9]+$ ]] || return 2
    printf '%s\n' "$value"
}

threshold_functional() {
    local node="$1"
    [[ -w "$node" ]] || return 1
    threshold_read "$node" >/dev/null
}

threshold_apply() {
    local node="$1" want="$2" got=""
    printf '%s\n' "$want" > "$node" 2>/dev/null || return 1
    got=$(threshold_read "$node") || return 1
    [[ "$got" == "$want" ]]
}

battery_candidates() {
    local battery attribute
    for battery in "$POWER_SUPPLY_ROOT"/*; do
        [[ -d "$battery" ]] || continue
        if [[ -r "$battery/type" ]]; then
            [[ $(cat "$battery/type") == Battery ]] || continue
        else
            [[ ${battery##*/} == BAT* ]] || continue
        fi
        for attribute in "${ATTRIBUTES[@]}"; do
            [[ -e "$battery/$attribute" ]] && printf '%s\n' "$battery/$attribute"
        done
    done
    return 0
}

write_state() {
    local limit="$1" mechanism="$2" reason="$3"
    local nodes_seen="$4" nodes_written="$5" nodes_refused="$6"
    local tmp=""

    install -d -m 0755 "$STATE_DIR"
    tmp=$(mktemp "$STATE_FILE.XXXXXX")
    {
        printf 'limit=%s\n' "$limit"
        printf 'reason=%s\n' "$reason"
        printf 'mechanism=%s\n' "$mechanism"
        printf 'nodes_seen=%s\n' "$nodes_seen"
        printf 'nodes_written=%s\n' "$nodes_written"
        printf 'nodes_refused=%s\n' "$nodes_refused"
    } > "$tmp"
    chmod 0644 "$tmp"
    mv -f "$tmp" "$STATE_FILE"
}

apply_limit() {
    local limit="$1"
    local node value status mechanism=none reason=firmware_unsupported
    local functional_nodes=0 applied_nodes=0 rejected_nodes=0

    local battery_lock
    exec {battery_lock}>"$STATE_DIR/battery-charge-limit.lock"
    flock -w 20 -x "$battery_lock"
    while read -r node; do
        [[ -n "$node" ]] || continue
        if value=$(threshold_read "$node"); then
            if ! threshold_functional "$node"; then
                functional_nodes=$((functional_nodes + 1))
                rejected_nodes=$((rejected_nodes + 1))
                continue
            fi
        else
            status=$?
            if ((status == 1)); then
                functional_nodes=$((functional_nodes + 1))
                rejected_nodes=$((rejected_nodes + 1))
            fi
            continue
        fi
        functional_nodes=$((functional_nodes + 1))
        if [[ "$value" == "$limit" ]] || threshold_apply "$node" "$limit"; then
            applied_nodes=$((applied_nodes + 1))
            if [[ "$mechanism" == none ]]; then
                mechanism="sysfs:${node}"
            fi
        else
            rejected_nodes=$((rejected_nodes + 1))
        fi
    done < <(battery_candidates)

    if ((applied_nodes > 0)); then
        reason=applied
        if ((rejected_nodes > 0)); then
            reason=partial
        fi
    elif ((functional_nodes > 0)); then
        reason=write_rejected
    fi

    write_state "$limit" "$mechanism" "$reason" "$functional_nodes" "$applied_nodes" "$rejected_nodes"

    if ((functional_nodes == 0)); then
        return 0
    fi
    ((applied_nodes > 0 && rejected_nodes == 0))
}

state_get() {
    local key="$1" value=""
    [[ -r "$STATE_FILE" ]] || return 1
    value=$(sed -n "s/^${key}=//p" "$STATE_FILE" | head -n 1)
    [[ -n "$value" ]] || return 1
    printf '%s\n' "$value"
}

live_probe() {
    local want="$1"
    local node value status
    local functional_nodes=0 drift=no

    while read -r node; do
        [[ -n "$node" ]] || continue
        if value=$(threshold_read "$node"); then
            :
        else
            status=$?
            if ((status == 1)); then
                drift=yes
            fi
            continue
        fi
        functional_nodes=$((functional_nodes + 1))
        if [[ "$value" != "$want" ]]; then
            drift=yes
        fi
    done < <(battery_candidates)

    printf '%s\n%s\n' "$functional_nodes" "$drift"
}

query_key() {
    local key="$1"
    local limit state_limit live probe_functional probe_drift

    limit=$(resolve_limit)
    state_get limit >/dev/null || return 1

    case "$key" in
        limit)
            printf '%s\n' "$limit"
            ;;
        state_limit)
            state_get limit
            ;;
        reason|mechanism|nodes_seen|nodes_written|nodes_refused)
            state_get "$key"
            ;;
        enforced|functional_nodes|drift)
            live=$(live_probe "$limit")
            probe_functional="${live%%$'\n'*}"
            probe_drift="${live##*$'\n'}"
            case "$key" in
                functional_nodes) printf '%s\n' "$probe_functional" ;;
                drift) printf '%s\n' "$probe_drift" ;;
                enforced)
                    if [[ "$probe_functional" != "0" && "$probe_drift" == no ]]; then
                        printf 'yes\n'
                    else
                        printf 'no\n'
                    fi
                    ;;
            esac
            ;;
        *)
            return 2
            ;;
    esac
}

mode="${1:---apply}"
case "$mode" in
    --apply|apply)
        install -d -m 0755 "$STATE_DIR"
        apply_limit "$(resolve_limit)"
        ;;
    --query|query)
        [[ $# -eq 2 ]] || { usage; exit 2; }
        query_key "$2"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage
        exit 2
        ;;
esac
