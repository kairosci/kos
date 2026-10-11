#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export SANDBOX PROJECT_ROOT
mkdir -p "$SANDBOX/home/tester" "$SANDBOX/runtime"
sed -e "s|/etc/|$SANDBOX/etc/|g" \
    -e "s|/home/\*|$SANDBOX/home/*|g" \
    -e "s|/run/user/|$SANDBOX/runtime/|g" \
    "$PROJECT_ROOT/scripts/lib/modules/92-responsiveness.sh" > "$SANDBOX/module.sh"
cat > "$SANDBOX/run.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
log() { printf '%s\n' "$*" >> "$SANDBOX/log"; }
err() { printf '%s\n' "$*" >&2; exit 1; }
id() { printf '1000\n'; }
systemctl() {
    printf '%s\n' "$*" >> "$SANDBOX/calls"
    [[ "${FAIL_SYSTEMCTL:-}" != "$1" ]]
}
user_as() {
    printf '%s\n' "$*" >> "$SANDBOX/users"
    [[ "${FAIL_USER:-0}" == 0 ]]
}
source "$SANDBOX/module.sh"
SH
test_section "Desktop responsiveness"
assert_true "module installs configuration successfully" 'bash "$SANDBOX/run.sh"'
assert_true "all installed templates match the repository" 'cmp -s "$PROJECT_ROOT/conf/performance/data/oomd.conf" "$SANDBOX/etc/systemd/oomd.conf.d/90-kos.conf" && for slice in app background session; do cmp -s "$PROJECT_ROOT/conf/performance/data/$slice.slice.conf" "$SANDBOX/etc/systemd/user/$slice.slice.d/90-kos.conf" || exit 1; done'
assert_file_contains_literal "daemon is enabled and started" "$SANDBOX/calls" 'enable --now systemd-oomd.socket systemd-oomd.service'
assert_file_contains_literal "new daemon configuration is applied" "$SANDBOX/calls" 'restart systemd-oomd.service'
assert_file_contains_literal "inactive session is explicitly deferred" "$SANDBOX/log" 'performance.session_deferred tester'
assert_true "memory protection extends through the session ancestors" 'for slice in user user-; do cmp -s "$PROJECT_ROOT/conf/performance/data/memory.slice.conf" "$SANDBOX/etc/systemd/system/$slice.slice.d/90-kos-memory.conf" || exit 1; done; cmp -s "$PROJECT_ROOT/conf/performance/data/memory.slice.conf" "$SANDBOX/etc/systemd/user/session.slice.d/90-kos-memory.conf" && grep -qxF '\''[Service]'\'' "$SANDBOX/etc/systemd/system/user@.service.d/90-kos-memory.conf" && grep -qxF '\''MemoryLow=512M'\'' "$SANDBOX/etc/systemd/system/user@.service.d/90-kos-memory.conf"'
first_hash=$(find "$SANDBOX/etc" -type f -exec sha256sum {} + | sort)
first_restarts=$(grep -c '^restart ' "$SANDBOX/calls")
assert_true "repeat setup preserves files and avoids restarting an unchanged daemon" 'bash "$SANDBOX/run.sh" && [[ "$first_hash" == "$(find "$SANDBOX/etc" -type f -exec sha256sum {} + | sort)" && "$first_restarts" == "$(grep -c '\''^restart '\'' "$SANDBOX/calls")" ]]'
assert_false "manager reload failure stops provisioning" 'FAIL_SYSTEMCTL=daemon-reload bash "$SANDBOX/run.sh"'
assert_false "daemon startup failure stops provisioning" 'FAIL_SYSTEMCTL=enable bash "$SANDBOX/run.sh"'
assert_file_not_contains "module never restarts desktop or audio" "$SANDBOX/calls" 'restart.*(hypr|pipewire|wireplumber|dbus)'
mkdir -p "$SANDBOX/runtime/1000"
touch "$SANDBOX/runtime/1000/bus"
sed -i 's/\[\[ -S /[[ -f /' "$SANDBOX/module.sh"
assert_true "active session manager is reloaded through user_as" 'bash "$SANDBOX/run.sh" && grep -qxF '\''tester systemctl --user daemon-reload'\'' "$SANDBOX/users"'
assert_false "active session reload failure remains visible" 'FAIL_USER=1 bash "$SANDBOX/run.sh"'

# shellcheck source=scripts/lib/responsiveness.sh
source "$PROJECT_ROOT/scripts/lib/responsiveness.sh"
# shellcheck disable=SC2329
systemctl() {
    if [[ "$1" == show ]]; then
        printf '%s\n' "${TEST_PARENT_LOW:-536870912}"
        return 0
    fi
    [[ "$1" == --user ]] || return 0
    case "$5" in
        ManagedOOMMemoryPressure) [[ "$3" == session.slice ]] && printf 'auto\n' || printf 'kill\n' ;;
        ManagedOOMSwap) [[ "$3" == session.slice ]] && printf 'auto\n' || printf '%s\n' "${TEST_SWAP_MODE:-kill}" ;;
        ManagedOOMMemoryPressureLimit) printf '1717986918\n' ;;
        CPUWeight|IOWeight) printf '200\n' ;;
        MemoryLow) printf '536870912\n' ;;
        *) return 1 ;;
    esac
}
# shellcheck disable=SC2329
oomctl() { printf 'Swap Used Limit: %s\nDefault Memory Pressure Limit: 40.00%%\nDefault Memory Pressure Duration: 10s\n' "${TEST_SWAP_LIMIT:-80.00%}"; }
assert_true "runtime verifier accepts effective policy" 'responsiveness_runtime "$PROJECT_ROOT"'
assert_false "runtime verifier rejects daemon threshold drift" 'TEST_SWAP_LIMIT=90.00% responsiveness_runtime "$PROJECT_ROOT"'
assert_false "runtime verifier rejects disabled application swap monitoring" 'TEST_SWAP_MODE=auto responsiveness_runtime "$PROJECT_ROOT"'
assert_false "runtime verifier rejects unprotected session ancestors" 'TEST_PARENT_LOW=0 responsiveness_runtime "$PROJECT_ROOT"'
sed 's/\$EUID/${RESPONSIVENESS_TEST_EUID}/g' "$PROJECT_ROOT/scripts/lib/responsiveness.sh" > "$SANDBOX/responsiveness.sh"
source "$SANDBOX/responsiveness.sh"
RESPONSIVENESS_TEST_EUID=0
TARGET_USER=tester
TARGET_UID=1000
# shellcheck disable=SC2329
id() { printf '1000\n'; }
# shellcheck disable=SC2329
runuser() {
    [[ ${TEST_RUNUSER_FAIL:-0} == 0 ]] || return 1
    [[ "$1" == -u && "$2" == tester && "$3" == -- && "$4" == env &&
        "$5" == XDG_RUNTIME_DIR=/run/user/1000 &&
        "$6" == DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus && "$7" == systemctl ]] || return 1
    shift 7
    systemctl "$@"
}
assert_true "root verifier inspects the target account with its session environment" 'responsiveness_runtime "$PROJECT_ROOT"'
assert_false "root verifier propagates failure to enter the target account" 'TEST_RUNUSER_FAIL=1 responsiveness_runtime "$PROJECT_ROOT"'
test_summary
