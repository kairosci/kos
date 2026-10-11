#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
source "$PROJECT_DIR/scripts/lib/distribution.sh"
source "$PROJECT_DIR/scripts/lib/release.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
releng="$SANDBOX/releng"
output="$SANDBOX/output"
profile="$SANDBOX/build/profile"
mkdir -p "$releng/airootfs/etc/mkinitcpio.d" "$releng/efiboot/loader/entries" "$output" "$SANDBOX/build" "$SANDBOX/runtime/usr/share/kos"
printf 'iso_name=archlinux\n' > "$releng/profiledef.sh"
printf '[options]\n[core]\n[extra]\n' > "$releng/pacman.conf"
printf 'base\nlinux\n' > "$releng/packages.x86_64"
printf 'linux /arch/boot/x86_64/vmlinuz-linux\ninitrd /arch/boot/x86_64/initramfs-linux.img\n' > "$releng/efiboot/loader/entries/live.conf"
printf 'ALL_kver=/boot/vmlinuz-linux\ndefault_image=/boot/initramfs-linux.img\n' > "$releng/airootfs/etc/mkinitcpio.d/linux.preset"
printf '0.1.0\n' > "$SANDBOX/runtime/usr/share/kos/version"
package="$output/kos-0.1.0-1-x86_64.pkg.tar.zst"
bsdtar -cf "$package" -C "$SANDBOX/runtime" .
repo-add() {
    [[ $# == 4 ]] || return 1
    printf 'fixture repository\n' > "$1"
}
test_section "kos Release Profile"
assert_false "profile rejects a missing custom kernel" 'kos_release_profile "$PROJECT_DIR" "$profile" "$package" "$releng"'
assert_false "failed preflight leaves no partial profile" '[[ -e "$profile" ]]'
touch "$output/linux-kos-7.2.5-3-x86_64.pkg.tar.zst" "$output/linux-kos-headers-7.2.5-3-x86_64.pkg.tar.zst"
assert_true "complete package set produces a release profile" 'kos_release_profile "$PROJECT_DIR" "$profile" "$package" "$releng"'
assert_true "custom kernel is installed through the build repository" 'grep -qx linux-kos "$profile/packages.x86_64" && grep -qx kos "$profile/packages.x86_64" && ! grep -qx linux "$profile/packages.x86_64" && grep -q "Server = file://" "$profile/pacman.conf"'
assert_true "live initramfs retains Archiso hooks instead of installed system hooks" 'grep -q "NoExtract = etc/mkinitcpio.conf.d/kos_hooks.conf" "$profile/pacman.conf" && [[ ! -e "$profile/airootfs/etc/mkinitcpio.conf.d/kos_hooks.conf" && -L "$profile/airootfs/etc/pacman.d/hooks/80-limine-efi-deploy.hook" ]]'
assert_true "live boot entries and initramfs use the custom kernel" 'grep -q vmlinuz-linux-kos "$profile/efiboot/loader/entries/live.conf" && grep -q initramfs-linux-kos.img "$profile/airootfs/etc/mkinitcpio.d/linux-kos.preset" && [[ ! -e "$profile/airootfs/etc/mkinitcpio.d/linux.preset" ]]'
assert_true "installer receives runtime kernel and headers" '[[ $(find "$profile/airootfs/opt/kos" -name "*.pkg.tar.zst" | wc -l) == 3 ]]'
assert_true "live identity preserves the vendor package boundary" 'grep -qx ID=kos "$profile/airootfs/etc/os-release" && [[ ! -e "$profile/airootfs/usr/lib/os-release" && ! -e "$profile/airootfs/var/lib/kos/os-identity" ]]'
assert_true "boot verification is enabled without a target ordering cycle" '[[ -L "$profile/airootfs/etc/systemd/system/multi-user.target.wants/kos-boot-check.service" ]] && ! grep -q After=multi-user "$profile/airootfs/etc/systemd/system/kos-boot-check.service"'
assert_false "existing profile is never overwritten" 'kos_release_profile "$PROJECT_DIR" "$profile" "$package" "$releng"'
test_summary
