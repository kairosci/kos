#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KERNEL_MODULE="$PROJECT_DIR/scripts/lib/modules/50-kernel.sh"
KERNEL_POLICY="$PROJECT_DIR/data/component/security/kernel.json"
KERNEL_COMPONENT="$PROJECT_DIR/src/component/security/kernel.lua"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Kernel Sysctl Hardening & Limits"

assert_file_exists "kernel module exists" "$KERNEL_MODULE"
assert_file_contains "kernel module delegates to Lua" "$KERNEL_MODULE" "apply-kernel"
assert_file_exists "kernel policy exists" "$KERNEL_POLICY"
assert_file_exists "kernel Lua component exists" "$KERNEL_COMPONENT"
assert_file_contains "kernel policy configures randomize_va_space" "$KERNEL_POLICY" "kernel.randomize_va_space = 2"
assert_file_contains "kernel policy configures kptr_restrict" "$KERNEL_POLICY" "kernel.kptr_restrict = 2"
assert_file_contains "kernel policy configures dmesg_restrict" "$KERNEL_POLICY" "kernel.dmesg_restrict = 1"
assert_file_contains "kernel policy configures perf_event_paranoid" "$KERNEL_POLICY" "kernel.perf_event_paranoid = 3"
assert_file_contains "kernel policy configures unprivileged_bpf_disabled" "$KERNEL_POLICY" "kernel.unprivileged_bpf_disabled = 1"
assert_file_contains "kernel policy configures ptrace_scope" "$KERNEL_POLICY" "kernel.yama.ptrace_scope = 1"
assert_file_contains "kernel policy configures sysrq" "$KERNEL_POLICY" "kernel.sysrq = 16"
assert_file_contains "kernel policy disables coredump" "$KERNEL_POLICY" "DefaultLimitCORE=0"

if [[ -f /etc/sysctl.d/99-security.conf ]]; then
    assert_file_exists "sysctl 99-security.conf exists on system" "/etc/sysctl.d/99-security.conf"
    assert_file_exists "sysctl 99-lockdown.conf exists on system" "/etc/sysctl.d/99-lockdown.conf"
fi

if [[ -f /etc/security/limits.d/99-no-core.conf ]]; then
    assert_file_exists "limits 99-no-core.conf exists on system" "/etc/security/limits.d/99-no-core.conf"
    assert_file_contains "limits.d/99-no-core.conf has hard core 0" "/etc/security/limits.d/99-no-core.conf" "hard[[:space:]]+core[[:space:]]+0"
    assert_file_contains "limits.d/99-no-core.conf has soft core 0" "/etc/security/limits.d/99-no-core.conf" "soft[[:space:]]+core[[:space:]]+0"
fi

check_sysctl_live() {
    local key="$1" expected="$2"
    local path="/proc/sys/${key//./\/}"
    [[ -f "$path" ]] || return 0
    local val
    test_priv true &>/dev/null || return 2
    val=$(test_priv sysctl -n "$key" 2>/dev/null)
    [[ "$val" == "$expected" ]]
}

if [[ -f /etc/sysctl.d/99-security.conf ]] && test_priv true &>/dev/null; then
    assert_true "live kernel.randomize_va_space = 2" "check_sysctl_live kernel.randomize_va_space 2"
    assert_true "live kernel.kptr_restrict = 2" "check_sysctl_live kernel.kptr_restrict 2"
    assert_true "live kernel.dmesg_restrict = 1" "check_sysctl_live kernel.dmesg_restrict 1"
    assert_true "live kernel.perf_event_paranoid = 3" "check_sysctl_live kernel.perf_event_paranoid 3"
    assert_true "live kernel.unprivileged_bpf_disabled = 1" "check_sysctl_live kernel.unprivileged_bpf_disabled 1"
    assert_true "live kernel.yama.ptrace_scope = 1" "check_sysctl_live kernel.yama.ptrace_scope 1"
    assert_true "live kernel.sysrq = 16" "check_sysctl_live kernel.sysrq 16"
    assert_true "live fs.suid_dumpable = 0" "check_sysctl_live fs.suid_dumpable 0"
    assert_true "live net.ipv4.conf.all.rp_filter = 1" "check_sysctl_live net.ipv4.conf.all.rp_filter 1"
    assert_true "live net.ipv4.tcp_syncookies = 1" "check_sysctl_live net.ipv4.tcp_syncookies 1"
    assert_true "live net.ipv4.tcp_rfc1337 = 1" "check_sysctl_live net.ipv4.tcp_rfc1337 1"
elif [[ -f /etc/sysctl.d/99-security.conf ]]; then
    assert_warn "Live sysctl checks require root access" "false"
fi

test_summary
