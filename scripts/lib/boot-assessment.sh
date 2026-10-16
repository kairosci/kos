#!/usr/bin/env bash
set -euo pipefail

boot_assessment() {
    local destination="$1"
    [[ $EUID -eq 0 ]] || err "__root_required"
    install -d -m 700 "$destination"
    findmnt --json / > "$destination/root.json"
    findmnt --json /boot > "$destination/boot.json"
    efibootmgr -v > "$destination/firmware.txt"
    lsblk --json --output NAME,TYPE,FSTYPE,UUID,PARTUUID,MOUNTPOINTS > "$destination/devices.json"
    cat /proc/cmdline > "$destination/current-cmdline.txt"
    for file in /etc/default/limine /etc/mkinitcpio.conf /etc/default/grub; do
        [[ ! -f "$file" ]] || install -m 600 "$file" "$destination/${file##*/}"
    done
    find /boot -maxdepth 4 -type f -printf '%P\t%s\n' > "$destination/boot-files.tsv"
    [[ ! -f /boot/limine.conf ]] || install -m 600 /boot/limine.conf "$destination/limine.conf"
    for file in /etc/mkinitcpio.d/*.preset; do
        [[ ! -f "$file" ]] || install -m 600 "$file" "$destination/${file##*/}"
    done
    env -u RUBYOPT -u RUBYLIB ruby "$PROJECT_DIR/modules/platform/arch/scripts/boot-menu.rb" report /boot/limine.conf /boot > "$destination/verified-menu.json"
    jq '{entries:(.entries|length),trialBootVerified}' "$destination/verified-menu.json"
}
