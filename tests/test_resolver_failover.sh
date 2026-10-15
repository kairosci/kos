#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export RESOLVER_FAILOVER_STATE_DIR="$SANDBOX/state"
source "$PROJECT_DIR/scripts/lib/resolver-failover.sh"

NETWORK_STATE=connected
NETWORK_CONNECTIVITY=full
DNS_PROVIDER=Cloudflare
DNS_FAIL=1
OMARCHY_FAIL=0
POST_SWITCH_FAIL=0
DNS_CALLS=0
OMARCHY_CALLS=0
SLEEP_CALLS=0
NOW=1000
NMCLI_FAIL=0

nmcli() {
    [[ "$NMCLI_FAIL" == 0 ]] || return 1
    case "$1 $2 $3" in
        '-t -f STATE') printf '%s\n' "$NETWORK_STATE" ;;
        '-t -f CONNECTIVITY') printf '%s\n' "$NETWORK_CONNECTIVITY" ;;
        *) return 2 ;;
    esac
}

resolvectl() {
    [[ "$1 $2 $3" == '--cache=no --type=A query' ]] || return 2
    DNS_CALLS=$((DNS_CALLS + 1))
    [[ "$DNS_FAIL" == 0 ]]
}

omarchy() {
    if [[ $# -eq 1 && "$1" == dns ]]; then
        printf '%s\n' "$DNS_PROVIDER"
        return 0
    fi
    if [[ $# -eq 2 && "$1" == dns ]]; then
        OMARCHY_CALLS=$((OMARCHY_CALLS + 1))
        [[ "$OMARCHY_FAIL" == 0 ]] || return 1
        DNS_PROVIDER="$2"
        DNS_FAIL="$POST_SWITCH_FAIL"
        return 0
    fi
    return 2
}

date() {
    [[ "$1" == +%s ]] || return 2
    printf '%s\n' "$NOW"
}

sleep() {
    SLEEP_CALLS=$((SLEEP_CALLS + 1))
}

reset_fixture() {
    rm -rf "$RESOLVER_FAILOVER_STATE_DIR"
    NETWORK_STATE=connected
    NETWORK_CONNECTIVITY=full
    DNS_PROVIDER=Cloudflare
    DNS_FAIL=1
    OMARCHY_FAIL=0
    POST_SWITCH_FAIL=0
    DNS_CALLS=0
    OMARCHY_CALLS=0
    SLEEP_CALLS=0
    NOW=1000
    NMCLI_FAIL=0
}

fail_probes() {
    resolver_failover_check_once >/dev/null 2>&1
}

test_section "DNS Resolver Failover"

reset_fixture
DNS_FAIL=0
assert_true "healthy resolver leaves provider unchanged" "resolver_failover_check_once; [[ \$DNS_PROVIDER == Cloudflare && \$OMARCHY_CALLS == 0 ]]"
assert_true "healthy resolver writes a zero failure count" "[[ \$(cat '$RESOLVER_FAILOVER_FAILURES') == 0 ]]"
assert_true "probe tests multiple independent update domains" "[[ \${#RESOLVER_FAILOVER_PROBE_HOSTS[@]} -eq 3 && \${RESOLVER_FAILOVER_PROBE_HOSTS[*]} == 'archlinux.org github.com herdr.dev' ]]"

reset_fixture
NETWORK_STATE=disconnected
assert_true "disconnected network defers resolver switching" "resolver_failover_check_once >/dev/null; [[ \$OMARCHY_CALLS == 0 ]]"
assert_true "offline check clears stale failure count" "[[ \$(cat '$RESOLVER_FAILOVER_FAILURES') == 0 ]]"

reset_fixture
NETWORK_CONNECTIVITY=none
assert_true "connected local network without internet does not switch providers" "resolver_failover_check_once >/dev/null; [[ \$OMARCHY_CALLS == 0 ]]"
assert_true "no-internet state clears stale probe failures" "[[ \$(cat '$RESOLVER_FAILOVER_FAILURES') == 0 ]]"

reset_fixture
NETWORK_CONNECTIVITY=limited
assert_true "limited connectivity still permits DNS failover checks" "fail_probes; [[ \$(cat '$RESOLVER_FAILOVER_FAILURES') == 1 ]]"

reset_fixture
assert_true "first failed probe only records one failure" "fail_probes; [[ \$(cat '$RESOLVER_FAILOVER_FAILURES') == 1 && \$OMARCHY_CALLS == 0 ]]"
assert_true "probe checks every configured update endpoint" "[[ \$DNS_CALLS == 3 ]]"
assert_true "second failed probe does not change provider" "fail_probes; [[ \$OMARCHY_CALLS == 0 && \$(cat '$RESOLVER_FAILOVER_FAILURES') == 2 ]]"
assert_true "third failed probe switches Cloudflare to Google" "fail_probes; [[ \$DNS_PROVIDER == Google && \$OMARCHY_CALLS == 1 ]]"
assert_true "successful switch records its cooldown timestamp" "[[ \$(cat '$RESOLVER_FAILOVER_LAST_SWITCH') == 1000 ]]"
assert_true "successful switch clears consecutive failures" "[[ \$(cat '$RESOLVER_FAILOVER_FAILURES') == 0 ]]"
assert_true "switch verification completes on the new provider" "[[ \$DNS_FAIL == 0 && \$SLEEP_CALLS == 0 ]]"

reset_fixture
POST_SWITCH_FAIL=1
assert_false "unhealthy fallback is reported after verification retries" "fail_probes; fail_probes; fail_probes"
assert_true "unhealthy fallback is probed three times before reporting" "[[ \$DNS_PROVIDER == Google && \$SLEEP_CALLS == 3 ]]"

reset_fixture
DNS_PROVIDER=Google
fail_probes
fail_probes
fail_probes
assert_true "Google switches back to Cloudflare" "[[ \$DNS_PROVIDER == Cloudflare ]]"

reset_fixture
DNS_PROVIDER=DHCP
fail_probes
fail_probes
fail_probes
assert_true "DHCP failure selects Cloudflare" "[[ \$DNS_PROVIDER == Cloudflare ]]"

reset_fixture
DNS_PROVIDER=Custom
fail_probes
fail_probes
fail_probes
assert_true "custom resolver failure selects Cloudflare" "[[ \$DNS_PROVIDER == Cloudflare ]]"

reset_fixture
resolver_failover_state_write "$RESOLVER_FAILOVER_FAILURES" 2
DNS_FAIL=0
assert_true "healthy probe resets accumulated failures" "resolver_failover_check_once; [[ \$(cat '$RESOLVER_FAILOVER_FAILURES') == 0 && \$OMARCHY_CALLS == 0 ]]"

reset_fixture
resolver_failover_state_write "$RESOLVER_FAILOVER_FAILURES" 3
resolver_failover_state_write "$RESOLVER_FAILOVER_LAST_SWITCH" 900
assert_true "recent provider switch respects cooldown" "fail_probes; [[ \$OMARCHY_CALLS == 0 ]]"
assert_true "cooldown keeps the failure count bounded" "[[ \$(cat '$RESOLVER_FAILOVER_FAILURES') == 3 ]]"

reset_fixture
resolver_failover_state_write "$RESOLVER_FAILOVER_FAILURES" invalid
assert_false "invalid failure state fails visibly" "resolver_failover_check_once"

reset_fixture
NMCLI_FAIL=1
assert_true "NetworkManager query errors defer resolver switching" "resolver_failover_check_once >/dev/null; [[ \$OMARCHY_CALLS == 0 ]]"

reset_fixture
DNS_PROVIDER=Unsupported
assert_false "unknown provider state prevents unsafe switching" "fail_probes; fail_probes; fail_probes"
assert_true "unknown provider does not call Omarchy DNS setter" "[[ \$OMARCHY_CALLS == 0 ]]"

reset_fixture
OMARCHY_FAIL=1
assert_false "provider update failure propagates" "fail_probes; fail_probes; fail_probes"
assert_true "failed provider update is rate limited" "fail_probes; [[ \$OMARCHY_CALLS == 1 ]]"

reset_fixture
resolver_failover_state_write "$RESOLVER_FAILOVER_FAILURES" 3
resolver_failover_state_write "$RESOLVER_FAILOVER_LAST_SWITCH" 1100
assert_false "future cooldown timestamp fails closed" "resolver_failover_in_cooldown"

assert_file_contains "system service runs resolver daemon" "$PROJECT_DIR/conf/network/data/os-resolver-failover.service" "ExecStart=/usr/local/libexec/os-resolver-failover"
assert_file_contains "setup module enables resolver daemon" "$PROJECT_DIR/scripts/lib/modules/81-resolver-failover.sh" "systemctl enable --now os-resolver-failover.service"
assert_file_contains "setup module provisions NetworkManager DNS integration directory" "$PROJECT_DIR/scripts/lib/modules/81-resolver-failover.sh" "install -d -m 0755 /etc/NetworkManager/conf.d"
assert_file_contains_literal "daemon uses native Omarchy DNS provider command" "$PROJECT_DIR/scripts/lib/resolver-failover.sh" 'omarchy dns "$next"'
assert_file_not_contains "daemon does not rewrite NetworkManager configuration directly" "$PROJECT_DIR/scripts/lib/resolver-failover.sh" '/etc/NetworkManager'

test_summary
