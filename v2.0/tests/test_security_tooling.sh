#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SEC_MODULE="$PROJECT_DIR/scripts/lib/modules/85-security-stack.sh"
POWER_MODULE="$PROJECT_DIR/scripts/lib/modules/90-hardware-power.sh"
MAINT_MODULE="$PROJECT_DIR/scripts/lib/modules/95-maintenance.sh"
AUDIT_MODULE="$PROJECT_DIR/scripts/lib/modules/94-security-audit.sh"
SECURITY_STACK_MODULE="$PROJECT_DIR/scripts/lib/modules/85-security-stack.sh"
SERVICES_MODULE="$PROJECT_DIR/scripts/lib/modules/80-services.sh"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Security Tooling, Isolation & Module Blacklists"

assert_file_exists "security stack module exists" "$SEC_MODULE"
assert_file_contains "security stack module delegates to Lua" "$SEC_MODULE" "apply-security-stack"
assert_file_contains "security policy defines audit rules" "$PROJECT_DIR/data/component/security/stack.json" "/etc/audit/rules.d/hardened.rules"
assert_file_contains "security stack generates initial USBGuard rules" "$PROJECT_DIR/src/component/security/stack.lua" "usbguardGenerate"
assert_file_contains "security policy configures fail2ban" "$PROJECT_DIR/data/component/security/stack.json" "packageFiles"
assert_file_contains "security policy defines AppArmor profiles" "$PROJECT_DIR/data/component/security/stack.json" "usr.bin.sshd"
assert_true "every apparmor profile includes abstractions/base for shared library loading" \
    "[[ \$(grep -c '#include <abstractions/base>' '$PROJECT_DIR/data/component/security/stack.json') -ge 4 ]]"
assert_true "every apparmor profile includes tunables/global" \
    "[[ \$(grep -c '#include <tunables/global>' '$PROJECT_DIR/data/component/security/stack.json') -ge 4 ]]"
assert_file_contains "AppArmor profiles are world readable" "$PROJECT_DIR/src/component/security/stack.lua" '"644"'
assert_file_not_contains "sshd AppArmor profile does not deny the privilege separation directory" "$PROJECT_DIR/data/component/security/stack.json" "deny /tmp/\*\* rw"

assert_file_exists "hardware power module exists" "$POWER_MODULE"
assert_file_contains "hardware module delegates security baseline to Lua" "$POWER_MODULE" "apply-security-baseline"
assert_file_contains "security baseline owns module blacklist application" "$PROJECT_DIR/src/component/security/baseline.lua" "moduleFiles"
assert_file_contains "security baseline declares module policy" "$PROJECT_DIR/data/component/security/baseline.json" "disable-usb-storage.conf"

assert_file_exists "maintenance module exists" "$MAINT_MODULE"
assert_file_exists "security audit module exists" "$AUDIT_MODULE"
assert_file_contains "security audit module delegates to Lua" "$AUDIT_MODULE" "apply-security-audit"
assert_file_contains "weekly audit service invokes Lua" "$PROJECT_DIR/data/component/security/audit.json" "run-security-audit"
assert_file_contains "weekly audit scans canonical system paths" "$PROJECT_DIR/data/component/security/audit.json" "/boot"
assert_file_contains "weekly audit declares vulnerability scanner" "$PROJECT_DIR/data/core/commands.json" "weeklyClamav"
assert_file_contains "weekly audit declares Arch advisory scanner" "$PROJECT_DIR/data/core/commands.json" "weeklyArchAuditReview"
assert_file_contains "weekly audit fails on advisory findings" "$PROJECT_DIR/src/component/security/audit.lua" "arch-audit-review"
assert_file_not_contains "auditd reload does not mistake a successful change check for unchanged rules" "$PROJECT_DIR/src/component/security/stack.lua" "augenrules --check"
assert_file_contains "auditd rules are reloaded through Lua" "$PROJECT_DIR/src/component/security/stack.lua" "auditRulesLoad"
assert_file_contains "merged audit rules clear prior rules before reload" "$PROJECT_DIR/data/component/security/stack.json" '"-D\\n'
assert_file_contains "service policy delegates to Lua" "$SERVICES_MODULE" "apply-services"
assert_file_contains "service policy is declared as external data" "$PROJECT_DIR/data/component/security/services.json" "avahi-daemon.service"
assert_file_contains "clamav update is deferred when freshclam already runs" "$PROJECT_DIR/src/component/security/stack.lua" "freshclamRunning"
assert_file_not_contains "auditd is not restarted via the missing initscripts service wrapper" "$SECURITY_STACK_MODULE" "service auditd restart"
assert_file_contains "SSH directory mode is declared in security policy" "$PROJECT_DIR/data/component/security/baseline.json" '"directory": \["/etc/ssh", "750"\]'
assert_file_contains "SSH file modes are applied by Lua" "$PROJECT_DIR/src/component/security/baseline.lua" "_applySshPermissions"
assert_file_not_contains "pacman cache cleanup no longer pipes yes through pipefail" "$MAINT_MODULE" "yes .. pacman -Scc"
assert_file_contains "pacman cache cleanup retains rollback packages" "$MAINT_MODULE" "paccache -rk2"
assert_file_contains "voxtype global disable is guarded on unit existence" "$MAINT_MODULE" "list-unit-files voxtype.service"
assert_file_contains "maintenance module hardens sudoers" "$MAINT_MODULE" "/etc/sudoers.d/security"

if command -v pacman &>/dev/null && [[ -f /etc/arch-release ]] && [[ -f /etc/audit/rules.d/hardened.rules ]]; then
    for pkg in lynis rkhunter clamav audit usbguard fail2ban apparmor; do
        assert_true "security package $pkg present" "pacman -Q '$pkg' &>/dev/null"
    done
fi

if [[ -f /etc/modprobe.d/disable-usb-storage.conf ]]; then
    assert_file_exists "USB storage blacklist conf exists" "/etc/modprobe.d/disable-usb-storage.conf"
    assert_file_exists "Unsafe protocols blacklist conf exists" "/etc/modprobe.d/disable-protocols.conf"
    assert_file_exists "FireWire blacklist conf exists" "/etc/modprobe.d/disable-firewire.conf"
    assert_file_exists "Legacy filesystems blacklist conf exists" "/etc/modprobe.d/disable-ramfs.conf"
fi

if [[ -f /etc/cron.weekly/security-audit.sh ]]; then
    assert_file_executable "Weekly audit cron script executable" "/etc/cron.weekly/security-audit.sh"
    assert_false "Nonexistent TPM verity file absent" "[[ -f /usr/lib/nvpcr/verity.nvpcr ]]"
fi

if [[ -f /etc/shadow ]]; then
    assert_true "Shadow file permissions 600" "[[ \"\$(stat -c %a /etc/shadow 2>/dev/null)\" == 600 ]]"
    assert_true "Passwd file permissions 644" "[[ \"\$(stat -c %a /etc/passwd 2>/dev/null)\" == 644 ]]"
    assert_true "Group file permissions 644" "[[ \"\$(stat -c %a /etc/group 2>/dev/null)\" == 644 ]]"
fi

test_summary
