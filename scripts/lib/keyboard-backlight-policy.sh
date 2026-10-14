#!/usr/bin/env bash
set -euo pipefail

install -d -m 755 -o root -g root /usr/local/lib/os/messages
install -m 644 -o root -g root "$PROJECT_ROOT/scripts/lib/i18n.sh" /usr/local/lib/os/
install -m 644 -o root -g root "$PROJECT_ROOT"/scripts/lib/messages/*.msg /usr/local/lib/os/messages/

log "power.keyboard"
install -Dm755 "$PROJECT_ROOT/scripts/lib/keyboard-backlight.sh" /usr/local/libexec/os-keyboard-backlight
install -Dm755 "$PROJECT_ROOT/scripts/lib/keyboard-backlight-resume.sh" /usr/lib/systemd/system-sleep/os-keyboard-backlight
cat > /etc/udev/rules.d/99-os-keyboard-backlight.rules << 'UDEV'
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*kbd_backlight*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="os-keyboard-backlight@$name.service"
UDEV
install -m 644 "$PROJECT_ROOT/conf/power/data/os-keyboard-backlight.service" \
    "$PROJECT_ROOT/conf/power/data/os-keyboard-backlight@.service" \
    "$PROJECT_ROOT/conf/power/data/os-keyboard-backlight.timer" /etc/systemd/system/
chmod 644 /etc/udev/rules.d/99-os-keyboard-backlight.rules \
    /etc/systemd/system/os-keyboard-backlight.{service,timer} \
    /etc/systemd/system/os-keyboard-backlight@.service
udevadm control --reload-rules
systemctl daemon-reload
systemctl enable os-keyboard-backlight.service
systemctl restart os-keyboard-backlight.service
systemctl enable --now os-keyboard-backlight.timer

