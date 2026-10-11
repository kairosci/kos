#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
AUTH_MODULE="$PROJECT_DIR/scripts/lib/modules/60-auth.sh"

source "$SCRIPT_DIR/test_lib.sh"

test_section "PAM Policies & Authentication Controls"

assert_file_exists "auth module exists" "$AUTH_MODULE"
assert_file_contains "auth module configures faillock.conf" "$AUTH_MODULE" "/etc/security/faillock.conf"
assert_file_contains "auth module sets faillock deny = 5" "$AUTH_MODULE" "deny[[:space:]]*=[[:space:]]*5"
assert_file_contains "auth module sets faillock unlock_time = 900" "$AUTH_MODULE" "unlock_time[[:space:]]*=[[:space:]]*900"
assert_file_contains "auth module configures pwquality.conf" "$AUTH_MODULE" "/etc/security/pwquality.conf"
assert_file_contains "auth module sets pwquality minlen = 14" "$AUTH_MODULE" "minlen[[:space:]]*=[[:space:]]*14"
assert_file_contains "auth module configures access.conf" "$AUTH_MODULE" "/etc/security/access.conf"

if [[ -f /etc/security/faillock.conf ]] && grep -qE '^[[:space:]]*deny[[:space:]]*=' /etc/security/faillock.conf 2>/dev/null; then
    assert_file_contains "live faillock deny threshold configured" "/etc/security/faillock.conf" "deny[[:space:]]*=[[:space:]]*5"
    assert_file_contains "live faillock unlock_time configured" "/etc/security/faillock.conf" "unlock_time[[:space:]]*=[[:space:]]*900"
fi

if [[ -f /etc/security/pwquality.conf ]] && grep -qE '^[[:space:]]*minlen[[:space:]]*=' /etc/security/pwquality.conf 2>/dev/null; then
    assert_file_contains "live pwquality minlen set" "/etc/security/pwquality.conf" "minlen[[:space:]]*=[[:space:]]*14"
    assert_file_contains "live pwquality minclass set" "/etc/security/pwquality.conf" "minclass[[:space:]]*=[[:space:]]*4"
fi

if [[ -f /etc/security/access.conf ]] && grep -qE '^\+:root:' /etc/security/access.conf 2>/dev/null; then
    assert_file_contains "live access.conf allows root" "/etc/security/access.conf" "\+:root:LOCAL"
    assert_file_contains "live access.conf allows wheel" "/etc/security/access.conf" "\+:wheel:LOCAL"
    assert_file_contains "live access.conf default deny" "/etc/security/access.conf" "\-:ALL:ALL"
fi

source "$PROJECT_DIR/scripts/lib/pam-policy.sh"
PAM_SANDBOX=$(mktemp -d)
trap 'rm -rf "$PAM_SANDBOX"' EXIT
PAM_TARGET="$PAM_SANDBOX/system-auth"
cat > "$PAM_TARGET" <<'PAM'
auth required pam_faillock.so preauth silent deny=10 unlock_time=120
auth [default=die] pam_faillock.so authfail deny=10 unlock_time=120
auth required pam_unix.so try_first_pass nullok
-password [success=1 default=ignore] pam_systemd_home.so
password required pam_unix.so try_first_pass nullok shadow
session required pam_unix.so
PAM
cp "$PAM_TARGET" "$PAM_SANDBOX/original"
assert_true "PAM policy migration succeeds" 'pam_policy_reconcile "$PAM_TARGET"'
assert_file_not_contains "faillock inline overrides are removed" "$PAM_TARGET" 'deny=|unlock_time='
assert_file_not_contains "empty passwords are no longer accepted" "$PAM_TARGET" 'nullok'
assert_file_contains "password quality is enforced before homed" "$PAM_TARGET" '^password requisite pam_pwquality.so retry=3 enforce_for_root$'
assert_file_contains "unix consumes the validated password" "$PAM_TARGET" 'pam_unix.so.*use_authtok'
assert_true "PAM backup preserves the original" 'cmp -s "$PAM_SANDBOX/original" "${PAM_TARGET}.omaconf-backup"'
cp "$PAM_TARGET" "$PAM_SANDBOX/applied"
assert_true "PAM migration is idempotent" 'pam_policy_reconcile "$PAM_TARGET" && cmp -s "$PAM_TARGET" "$PAM_SANDBOX/applied"'
printf 'auth required pam_unix.so\n' > "$PAM_TARGET"
cp "$PAM_TARGET" "$PAM_SANDBOX/unsupported"
assert_false "unsupported PAM stacks are rejected" 'pam_policy_reconcile "$PAM_TARGET"'
assert_true "rejected stacks are preserved" 'cmp -s "$PAM_TARGET" "$PAM_SANDBOX/unsupported"'

test_summary
