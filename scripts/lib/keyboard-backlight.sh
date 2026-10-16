#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
OS_I18N_BOOT="${OS_I18N_BOOT:-/usr/local/lib/os/i18n.sh}"
if [[ $EUID -eq 0 ]]; then
    OS_I18N_BOOT=/usr/local/lib/os/i18n.sh
    if [[ -f "$OS_I18N_BOOT" ]]; then
        export OS_I18N_DIR=/usr/local/lib/os/messages
    elif [[ -d "$SCRIPT_DIR/../../data/catalog" ]]; then
        export OS_I18N_DIR="$SCRIPT_DIR/../../data/catalog"
    else
        export OS_I18N_DIR="$SCRIPT_DIR/messages"
    fi
fi
if [[ -f "$OS_I18N_BOOT" ]]; then
    # shellcheck source=i18n.sh
    source "$OS_I18N_BOOT"
    locale_init
else
    source "$SCRIPT_DIR/i18n.sh"
    locale_init
fi

mode="${1:-apply}"
[[ $# -le 1 ]] || err "power.keyboard_invalid_args"
case "$mode" in
    apply|--check) ;;
    --awake)
        if systemctl is-active --quiet sleep.target; then
            exit 0
        else
            status=$?
            [[ $status -eq 3 ]] || exit "$status"
        fi
        ;;
    *) err "power.keyboard_invalid_args" ;;
esac

found=0
for led in "${OS_KEYBOARD_LEDS_ROOT:-/sys/class/leds}"/*kbd_backlight*; do
    [[ -e "$led" ]] || continue
    found=1
    maximum=$(cat "$led/max_brightness") || err "power.keyboard_failed" "$led"
    current=$(cat "$led/brightness") || err "power.keyboard_failed" "$led"
    [[ "$maximum" =~ ^[1-9][0-9]{0,8}$ && "$current" =~ ^(0|[1-9][0-9]{0,8})$ ]] || err "power.keyboard_failed" "$led"
    if [[ "$current" != "$maximum" ]]; then
        [[ "$mode" != --check ]] || err "power.keyboard_failed" "$led"
        printf '%s\n' "$maximum" > "$led/brightness" || err "power.keyboard_failed" "$led"
        current=$(cat "$led/brightness") || err "power.keyboard_failed" "$led"
        [[ "$current" == "$maximum" ]] || err "power.keyboard_failed" "$led"
    fi
done
[[ $found -eq 1 ]] || log "power.keyboard_unsupported"
