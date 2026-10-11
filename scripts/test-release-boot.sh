#!/usr/bin/env bash
set -euo pipefail
OUTPUT=$(realpath -e "${1:?}")
source "$(dirname "$(readlink -f "$0")")/lib/i18n.sh"
i18n_init
command -v qemu-system-x86_64 >/dev/null || err release.tools qemu-system-x86_64
isos=("$OUTPUT"/kos-*.iso)
[[ ${#isos[@]} == 1 && -f ${isos[0]} ]] || err release.invalid
for firmware in bios uefi; do
    options=()
    if [[ "$firmware" == uefi ]]; then
        code=/usr/share/edk2/x64/OVMF_CODE.4m.fd
        vars=/usr/share/edk2/x64/OVMF_VARS.4m.fd
        [[ -f "$code" && -f "$vars" ]] || err release.tools edk2-ovmf
        cp "$vars" "$OUTPUT/OVMF_VARS.fd"
        options+=(-drive "if=pflash,format=raw,readonly=on,file=$code" -drive "if=pflash,format=raw,file=$OUTPUT/OVMF_VARS.fd")
    fi
    status=0
    timeout 180s qemu-system-x86_64 -machine q35 -accel tcg -m 3072 -smp 2 \
        -cdrom "${isos[0]}" -boot d -display none -serial stdio -monitor none \
        -no-reboot "${options[@]}" > "$OUTPUT/boot-$firmware.log" 2>&1 || status=$?
    [[ $status == 0 || $status == 124 ]] || err release.invalid
    grep -q 'KOS_BOOT_OK' "$OUTPUT/boot-$firmware.log" || err release.invalid
    printf 'kos boot %s passed\n' "$firmware"
done
rm -f "$OUTPUT/OVMF_VARS.fd"
