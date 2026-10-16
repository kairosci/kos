#!/usr/bin/env bash

Os::scripts::lib::resolver_failover_sh::run() {
set -euo pipefail

RESOLVER_FAILOVER_STATE_DIR="${RESOLVER_FAILOVER_STATE_DIR:-/run/os-resolver-failover}"
RESOLVER_FAILOVER_FAILURES="$RESOLVER_FAILOVER_STATE_DIR/failures"
RESOLVER_FAILOVER_LAST_SWITCH="$RESOLVER_FAILOVER_STATE_DIR/last-switch"
RESOLVER_FAILOVER_FAILURE_LIMIT=3
RESOLVER_FAILOVER_COOLDOWN=900
RESOLVER_FAILOVER_PROBE_HOSTS=(archlinux.org github.com herdr.dev)

RESOLVER_FAILOVER_LIB_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -r "$RESOLVER_FAILOVER_LIB_DIR/i18n.sh" ]]; then
    export OS_I18N_DIR="$RESOLVER_FAILOVER_LIB_DIR/messages"
    source "$RESOLVER_FAILOVER_LIB_DIR/i18n.sh"
elif [[ -r /usr/local/lib/os/i18n.sh ]]; then
    export OS_I18N_DIR=/usr/local/lib/os/messages
    source /usr/local/lib/os/i18n.sh
fi
i18n_init
unset RESOLVER_FAILOVER_LIB_DIR

resolver_failover_state_write() {
    local path="$1" value="$2" temporary
    install -d -m 0755 "$RESOLVER_FAILOVER_STATE_DIR"
    temporary=$(mktemp "$RESOLVER_FAILOVER_STATE_DIR/.state.XXXXXX")
    printf '%s\n' "$value" > "$temporary"
    chmod 0644 "$temporary"
    mv -f "$temporary" "$path"
}

resolver_failover_reset_failures() {
    resolver_failover_state_write "$RESOLVER_FAILOVER_FAILURES" 0
}

resolver_failover_network_connected() {
    local state connectivity
    state=$(nmcli -t -f STATE general) || return 1
    [[ "$state" == connected* ]] || return 1
    connectivity=$(nmcli -t -f CONNECTIVITY general) || return 1
    [[ "$connectivity" == full || "$connectivity" == limited ]]
}

resolver_failover_probe() {
    local hostname
    for hostname in "${RESOLVER_FAILOVER_PROBE_HOSTS[@]}"; do
        if resolvectl --cache=no --type=A query "$hostname" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

resolver_failover_current_provider() {
    local provider
    provider=$(omarchy dns) || return 1
    case "$provider" in
        Cloudflare|Google|DHCP|Custom) printf '%s\n' "$provider" ;;
        *) return 1 ;;
    esac
}

resolver_failover_next_provider() {
    case "$1" in
        Cloudflare) printf '%s\n' Google ;;
        Google) printf '%s\n' Cloudflare ;;
        DHCP|Custom) printf '%s\n' Cloudflare ;;
        *) return 1 ;;
    esac
}

resolver_failover_failure_count() {
    local count=0
    if [[ -f "$RESOLVER_FAILOVER_FAILURES" ]]; then
        IFS= read -r count < "$RESOLVER_FAILOVER_FAILURES" || return 1
    fi
    [[ "$count" =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$count"
}

resolver_failover_in_cooldown() {
    local now last
    [[ -f "$RESOLVER_FAILOVER_LAST_SWITCH" ]] || return 1
    IFS= read -r last < "$RESOLVER_FAILOVER_LAST_SWITCH" || return 1
    [[ "$last" =~ ^[0-9]+$ ]] || return 1
    now=$(date +%s) || return 1
    (( now >= last && now - last < RESOLVER_FAILOVER_COOLDOWN ))
}

resolver_failover_check_once() {
    local count current next now attempt
    if ! resolver_failover_network_connected; then
        resolver_failover_reset_failures
        log "dns.offline"
        return 0
    fi
    if resolver_failover_probe; then
        resolver_failover_reset_failures
        return 0
    fi
    count=$(resolver_failover_failure_count) || return 1
    if (( count < RESOLVER_FAILOVER_FAILURE_LIMIT )); then
        count=$((count + 1))
    fi
    resolver_failover_state_write "$RESOLVER_FAILOVER_FAILURES" "$count"
    if (( count < RESOLVER_FAILOVER_FAILURE_LIMIT )); then
        warn "dns.probe_failed" "$count" "$RESOLVER_FAILOVER_FAILURE_LIMIT"
        return 0
    fi
    if resolver_failover_in_cooldown; then
        log "dns.cooldown"
        return 0
    fi
    current=$(resolver_failover_current_provider) || return 1
    next=$(resolver_failover_next_provider "$current") || return 1
    now=$(date +%s) || return 1
    resolver_failover_state_write "$RESOLVER_FAILOVER_LAST_SWITCH" "$now"
    if ! omarchy dns "$next"; then
        resolver_failover_reset_failures
        warn "dns.switch_failed" "$current" "$next"
        return 1
    fi
    resolver_failover_reset_failures
    for attempt in 1 2 3; do
        if resolver_failover_probe; then
            log "dns.switched" "$current" "$next"
            return 0
        fi
        sleep 2
    done
    warn "dns.fallback_unavailable" "$next"
    return 1
}

resolver_failover_daemon() {
    while :; do
        resolver_failover_check_once || warn "dns.health_check_failed"
        sleep 60
    done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    resolver_failover_daemon
fi

}

Os::scripts::lib::resolver_failover_sh::run "$@"
