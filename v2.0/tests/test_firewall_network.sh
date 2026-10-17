#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FW_MODULE="$PROJECT_DIR/scripts/lib/modules/40-firewall.sh"
SSH_MODULE="$PROJECT_DIR/scripts/lib/modules/70-ssh.sh"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Firewall, Network & SSH Security"

assert_file_exists "firewall module exists" "$FW_MODULE"
assert_file_contains "firewall module sets default deny incoming" "$FW_MODULE" "ufw default deny incoming"
assert_file_not_contains "firewall reconciliation preserves existing rules" "$FW_MODULE" "ufw --force reset"
assert_file_contains "firewall module sets default allow outgoing" "$FW_MODULE" "ufw default allow outgoing"
assert_file_contains "firewall module enables ufw.service" "$FW_MODULE" "systemctl enable ufw.service"

assert_file_exists "ssh module exists" "$SSH_MODULE"
assert_file_contains "ssh module sets PermitRootLogin no" "$SSH_MODULE" "PermitRootLogin no"
assert_file_contains "ssh module sets PasswordAuthentication no" "$SSH_MODULE" "PasswordAuthentication no"
assert_file_contains "ssh module provisions systemd sandboxing" "$SSH_MODULE" "ProtectSystem=strict"

assert_false "NetworkManager configuration unmolested" "[[ -f /etc/NetworkManager/conf.d/security.conf ]]"
if ip link show lo &>/dev/null; then
    assert_true "Loopback network interface up" "ip link show lo 2>/dev/null | grep -q 'state UP\|state UNKNOWN'"
else
    assert_warn "Loopback network interface state unavailable in this execution context" "false"
fi
assert_warn "DNS resolution functional" "getent hosts archlinux.org &>/dev/null || resolvectl query archlinux.org &>/dev/null"

if systemctl list-unit-files ufw.service &>/dev/null; then
    assert_true "live UFW service is enabled" "systemctl is-enabled ufw.service &>/dev/null"
fi

if test_priv ufw status &>/dev/null; then
    assert_true "live UFW is active" "test_priv ufw status | grep -q 'Status: active'"
    assert_true "live UFW default deny incoming" "test_priv ufw status verbose | grep -q 'Default: deny (incoming)'"
    assert_true "live UFW default allow outgoing" "test_priv ufw status verbose | grep -q 'allow (outgoing)'"
fi

SSHD_CONF="/etc/ssh/sshd_config.d/hardened.conf"
if [[ -r "$SSHD_CONF" ]]; then
    assert_file_contains "live SSH PermitRootLogin disabled" "$SSHD_CONF" "^PermitRootLogin no"
    assert_file_contains "live SSH PasswordAuth disabled" "$SSHD_CONF" "^PasswordAuthentication no"
    assert_file_contains "live SSH PubkeyAuth enabled" "$SSHD_CONF" "^PubkeyAuthentication yes"
fi

if [[ -r "/etc/systemd/system/sshd.service.d/hardened.conf" ]]; then
    assert_file_contains "live SSHD ProtectSystem=strict" "/etc/systemd/system/sshd.service.d/hardened.conf" "ProtectSystem=strict"
    assert_file_contains "live SSHD ProtectHome=yes" "/etc/systemd/system/sshd.service.d/hardened.conf" "ProtectHome=yes"
    assert_file_contains "live SSHD NoNewPrivileges=yes" "/etc/systemd/system/sshd.service.d/hardened.conf" "NoNewPrivileges=yes"
fi

test_summary
