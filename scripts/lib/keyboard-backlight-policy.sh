#!/usr/bin/env bash
set -euo pipefail

install -d -m 755 -o root -g root /usr/local/lib/kos/messages
install -m 644 -o root -g root "$PROJECT_ROOT/scripts/lib/i18n.sh" /usr/local/lib/kos/
install -m 644 -o root -g root "$PROJECT_ROOT"/scripts/lib/messages/*.msg /usr/local/lib/kos/messages/

log "power.keyboard"
install -Dm755 "$PROJECT_ROOT/scripts/lib/keyboard-backlight.sh" /usr/local/libexec/kos-keyboard-backlight
install -Dm755 "$PROJECT_ROOT/scripts/lib/keyboard-backlight-resume.sh" /usr/lib/systemd/system-sleep/kos-keyboard-backlight
cat > /etc/udev/rules.d/99-kos-keyboard-backlight.rules << 'UDEV'
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*kbd_backlight*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="kos-keyboard-backlight@$name.service"
UDEV
install -m 644 "$PROJECT_ROOT/conf/power/data/kos-keyboard-backlight.service" \
    "$PROJECT_ROOT/conf/power/data/kos-keyboard-backlight@.service" \
    "$PROJECT_ROOT/conf/power/data/kos-keyboard-backlight.timer" /etc/systemd/system/
chmod 644 /etc/udev/rules.d/99-kos-keyboard-backlight.rules \
    /etc/systemd/system/kos-keyboard-backlight.{service,timer} \
    /etc/systemd/system/kos-keyboard-backlight@.service
udevadm control --reload-rules
systemctl daemon-reload
systemctl enable kos-keyboard-backlight.service
systemctl restart kos-keyboard-backlight.service
systemctl enable --now kos-keyboard-backlight.timer

