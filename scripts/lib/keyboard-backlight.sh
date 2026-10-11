#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
OMACONF_I18N_BOOT="${OMACONF_I18N_BOOT:-/usr/local/lib/omaconf/i18n.sh}"
if [[ $EUID -eq 0 ]]; then
    OMACONF_I18N_BOOT=/usr/local/lib/omaconf/i18n.sh
    if [[ -f "$OMACONF_I18N_BOOT" ]]; then
        export OMACONF_I18N_DIR=/usr/local/lib/omaconf/messages
    else
        export OMACONF_I18N_DIR="$SCRIPT_DIR/messages"
    fi
fi
if [[ -f "$OMACONF_I18N_BOOT" ]]; then
    # shellcheck source=i18n.sh
    source "$OMACONF_I18N_BOOT"
    i18n_init
else
    source "$SCRIPT_DIR/i18n.sh"
    i18n_init
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
for led in "${OMACONF_KEYBOARD_LEDS_ROOT:-/sys/class/leds}"/*kbd_backlight*; do
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
