#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/test_lib.sh"
source "$SCRIPT_DIR/../scripts/lib/os-identity.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/etc" "$SANDBOX/usr/lib"
printf 'NAME="Arch Linux"\nID=arch\nBUILD_ID=rolling\n' > "$SANDBOX/usr/lib/os-release"
printf 'NAME="previous desktop"\nID=previous\n' > "$SANDBOX/etc/os-release"
vendor_hash=$(sha256sum "$SANDBOX/usr/lib/os-release")
test_section "kos System Identity"
assert_true "kos identity replaces the local override" 'kos_identity_apply "$SANDBOX" 0.1.0'
assert_true "kos identity retains Arch ancestry" 'kos_identity_valid "$SANDBOX"'
assert_true "kos identity includes its release version" 'grep -qx '\''VERSION_ID="0.1.0"'\'' "$SANDBOX/etc/os-release"'
assert_true "original identity is preserved privately" 'grep -qx ID=previous "$SANDBOX/var/lib/kos/os-identity/os-release" && [[ $(stat -c %a "$SANDBOX/var/lib/kos/os-identity/os-release") == 600 ]]'
backup_hash=$(sha256sum "$SANDBOX/var/lib/kos/os-identity/os-release")
identity_hash=$(sha256sum "$SANDBOX/etc/os-release")
assert_true "identity reconciliation is idempotent" 'kos_identity_apply "$SANDBOX" 0.1.0 && [[ "$backup_hash" == "$(sha256sum "$SANDBOX/var/lib/kos/os-identity/os-release")" && "$vendor_hash" == "$(sha256sum "$SANDBOX/usr/lib/os-release")" && "$identity_hash" == "$(sha256sum "$SANDBOX/etc/os-release")" ]]'
assert_true "release upgrades update identity without replacing backup" 'kos_identity_apply "$SANDBOX" 0.2.0 && grep -qx '\''VERSION_ID="0.2.0"'\'' "$SANDBOX/etc/os-release" && [[ "$backup_hash" == "$(sha256sum "$SANDBOX/var/lib/kos/os-identity/os-release")" ]]'
assert_false "empty release version is rejected" 'kos_identity_apply "$SANDBOX"'
assert_false "shell syntax in a version is rejected" 'kos_identity_apply "$SANDBOX" '\''0.1.0;touch forbidden'\'''
printf 'ID=other\n' > "$SANDBOX/usr/lib/os-release"
assert_false "non Arch vendor identity is rejected" 'kos_identity_apply "$SANDBOX" 0.1.0'
rm "$SANDBOX/usr/lib/os-release"
assert_false "missing vendor metadata is rejected" 'kos_identity_apply "$SANDBOX" 0.1.0'
test_summary
