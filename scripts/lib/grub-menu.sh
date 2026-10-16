#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/bin:/usr/sbin:/bin:/sbin
[[ $EUID -eq 0 ]] || exit 1
esp=$(jq -er '.esp | select(.=="/boot")' /usr/share/os/boot-policy.json)
uuid=$(findmnt -nro UUID "$esp")
[[ -n "$uuid" ]] || exit 1
install -d -m 755 "$esp/grub"
stage=$(mktemp "$esp/grub/.os-menu.XXXXXX")
trap 'rm -f -- "$stage"' EXIT
env -u RUBYOPT -u RUBYLIB OS_I18N_DIR=/usr/share/os/lib/messages ruby /usr/share/os/modules/platform/arch/scripts/boot-menu.rb grub "$esp/limine.conf" "$esp" "$uuid" /usr/share/os/boot-policy.json > "$stage"
grub-script-check "$stage"
if [[ -f "$esp/grub/grub.cfg" ]] && ! cmp -s "$stage" "$esp/grub/grub.cfg"; then
    cp "$esp/grub/grub.cfg" "$esp/grub/grub.cfg.os-backup"
fi
mv -f -- "$stage" "$esp/grub/grub.cfg"
