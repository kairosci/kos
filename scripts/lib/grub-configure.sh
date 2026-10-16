#!/usr/bin/env bash

Os::scripts::lib::grub_configure_sh::run() {

set -euo pipefail

[[ $EUID -eq 0 ]] || { printf '%s\n' 'GRUB configuration requires root.' >&2; exit 1; }
grub_cfg=/etc/default/grub
managed=/usr/share/os/grub-defaults
[[ -s "$managed" ]] || { printf '%s\n' 'Managed GRUB defaults are missing.' >&2; exit 1; }
install -d -m 755 /etc/default
if [[ -e "$grub_cfg" && ! -e "$grub_cfg.os-backup" ]]; then
    cp -a -- "$grub_cfg" "$grub_cfg.os-backup"
fi
temporary=$(mktemp /etc/default/.grub.XXXXXX)
trap 'rm -f -- "$temporary"' EXIT
if [[ -f "$grub_cfg" ]]; then
    awk '
        !/^[[:space:]]*GRUB_(DEFAULT|TIMEOUT|TIMEOUT_STYLE|DISTRIBUTOR|TERMINAL|GFXMODE|CMDLINE_LINUX_DEFAULT|DISABLE_OS_PROBER|PRELOAD_MODULES)=/ { print }
    ' "$grub_cfg" > "$temporary"
fi
cat -- "$managed" >> "$temporary"
chmod 644 "$temporary"
mv -f -- "$temporary" "$grub_cfg"

}

Os::scripts::lib::grub_configure_sh::run "$@"
