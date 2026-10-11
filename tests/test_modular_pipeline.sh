#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MODULES_DIR="$PROJECT_DIR/scripts/lib/modules"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Modular Pipeline Architecture & Integrity"

EXPECTED_MODULES=(
    "00-env.sh"
    "05-locale.sh"
    "06-os-identity.sh"
    "10-debloat.sh"
    "20-defaults.sh"
    "22-portals.sh"
    "25-desktop-cleanup.sh"
    "30-theming.sh"
    "32-omaqt.sh"
    "35-shell-plugins.sh"
    "40-firewall.sh"
    "50-kernel.sh"
    "60-auth.sh"
    "62-keyring.sh"
    "70-ssh.sh"
    "80-services.sh"
    "85-security-stack.sh"
    "89-battery-charge.sh"
    "90-hardware-power.sh"
    "91-suspend-resume.sh"
    "92-responsiveness.sh"
    "95-maintenance.sh"
)

for m in "${EXPECTED_MODULES[@]}"; do
    mpath="$MODULES_DIR/$m"
    assert_file_exists "module $m exists" "$mpath"
    assert_file_executable "module $m is executable" "$mpath"
    assert_file_contains "module $m has strict mode" "$mpath" "set -euo pipefail"
    assert_file_contains "setup.sh references module $m" "$PROJECT_DIR/scripts/setup.sh" "$m"
done

assert_file_contains "00-env defines aur_verified_install" "$MODULES_DIR/00-env.sh" "aur_verified_install\(\)"
assert_file_contains "00-env defines omarchy_as helper" "$MODULES_DIR/00-env.sh" "omarchy_as\(\)"
assert_file_contains "omarchy_as forwards the user session bus" "$MODULES_DIR/00-env.sh" "DBUS_SESSION_BUS_ADDRESS"
assert_file_contains "20-defaults routes the browser through omarchy_as" "$MODULES_DIR/20-defaults.sh" "omarchy_as"
assert_file_contains "35-shell-plugins uses the canonical omamp source" "$MODULES_DIR/35-shell-plugins.sh" "omaconf/omamp.git"
assert_file_contains "35-shell-plugins routes through omarchy_as" "$MODULES_DIR/35-shell-plugins.sh" "omarchy_as"
assert_file_contains "32-omaqt tracks the omaqt checkout" "$MODULES_DIR/32-omaqt.sh" "OMAQT_DIR"
assert_file_contains "10-debloat defines DEBLOAT array" "$MODULES_DIR/10-debloat.sh" "DEBLOAT=\("
assert_file_contains "85-security-stack defines SECURITY_PKGS array" "$MODULES_DIR/85-security-stack.sh" "SECURITY_PKGS=\("
assert_file_contains "setup.sh checks EUID root requirement" "$PROJECT_DIR/scripts/setup.sh" "EUID -eq 0"

AUR_SANDBOX=$(mktemp -d)
trap 'rm -rf "$AUR_SANDBOX"' EXIT
# shellcheck source=/dev/null
source <(sed -n '/^aur_source_dependencies()/,/^}/p' "$MODULES_DIR/00-env.sh")
printf 'depends = gtk3\nmakedepends = patch\ndepends_x86_64 = libx11\ndepends_aarch64 = wrong-architecture\noptdepends = libreoffice: fonts\n' > "$AUR_SANDBOX/srcinfo"
assert_true "AUR selects required dependencies for the current architecture" "[[ \$(aur_source_dependencies '$AUR_SANDBOX/srcinfo' x86_64) == \$'gtk3\npatch\nlibx11' ]]"
assert_false "AUR propagates unreadable metadata" "aur_source_dependencies '$AUR_SANDBOX/missing' x86_64"
if command -v pacman >/dev/null; then
    # shellcheck source=/dev/null
    source <(sed -n '/^aur_package_artifact()/,/^}/p' "$MODULES_DIR/00-env.sh")
    mkdir -p "$AUR_SANDBOX/payload"
    printf 'pkgname = wanted-git\npkgver = 1-1\npkgdesc = Fixture\nsize = 0\narch = any\n' > "$AUR_SANDBOX/payload/.PKGINFO"
    tar -cf "$AUR_SANDBOX/wanted-0-1-any.pkg.tar.fixture" -C "$AUR_SANDBOX/payload" .PKGINFO
    assert_false "AUR rejects an artifact with a different package name" "aur_package_artifact '$AUR_SANDBOX' wanted"
    sed -i 's/wanted-git/wanted/' "$AUR_SANDBOX/payload/.PKGINFO"
    tar -cf "$AUR_SANDBOX/wanted-1-1-any.pkg.tar.fixture" -C "$AUR_SANDBOX/payload" .PKGINFO
    assert_true "AUR resolves the artifact from real pacman package metadata" "[[ \$(aur_package_artifact '$AUR_SANDBOX' wanted) == '$AUR_SANDBOX/wanted-1-1-any.pkg.tar.fixture' ]]"
fi

test_summary
