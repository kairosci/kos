#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FW_MODULE="$PROJECT_DIR/scripts/lib/modules/40-firewall.sh"
SSH_MODULE="$PROJECT_DIR/scripts/lib/modules/70-ssh.sh"
SSH_POLICY="$PROJECT_DIR/data/component/security/ssh.json"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Firewall, Network & SSH Security"

assert_file_exists "firewall module exists" "$FW_MODULE"
assert_file_contains "firewall module delegates policy to Lua" "$FW_MODULE" "apply-firewall"
assert_file_contains "firewall policy denies incoming and permits outgoing" "$PROJECT_DIR/data/component/security/firewall.json" '"incoming": "deny"'
assert_file_contains "firewall policy permits outgoing" "$PROJECT_DIR/data/component/security/firewall.json" '"outgoing": "allow"'
assert_file_not_contains "firewall component preserves existing rules" "$PROJECT_DIR/src/component/security/firewall.lua" "ufwReset"
assert_file_contains "firewall policy verifies the boot service" "$PROJECT_DIR/src/component/security/firewall.lua" "firewallServiceEnabledPrivileged"

assert_file_exists "ssh module exists" "$SSH_MODULE"
assert_file_contains "ssh module delegates to Lua" "$SSH_MODULE" "apply-ssh"
assert_file_contains "SSH policy disables root login" "$SSH_POLICY" "PermitRootLogin no"
assert_file_contains "SSH policy disables password authentication" "$SSH_POLICY" "PasswordAuthentication no"
assert_file_contains "SSH policy provisions systemd sandboxing" "$SSH_POLICY" "ProtectSystem=strict"

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
