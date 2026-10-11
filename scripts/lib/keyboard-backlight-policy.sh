#!/usr/bin/env bash
set -euo pipefail

install -d -m 755 -o root -g root /usr/local/lib/omaconf/messages
install -m 644 -o root -g root "$PROJECT_ROOT/scripts/lib/i18n.sh" /usr/local/lib/omaconf/
install -m 644 -o root -g root "$PROJECT_ROOT"/scripts/lib/messages/*.msg /usr/local/lib/omaconf/messages/

log "power.keyboard"
install -Dm755 "$PROJECT_ROOT/scripts/lib/keyboard-backlight.sh" /usr/local/libexec/omaconf-keyboard-backlight
install -Dm755 "$PROJECT_ROOT/scripts/lib/keyboard-backlight-resume.sh" /usr/lib/systemd/system-sleep/omaconf-keyboard-backlight
cat > /etc/udev/rules.d/99-omaconf-keyboard-backlight.rules << 'UDEV'
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="*kbd_backlight*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="omaconf-keyboard-backlight@$name.service"
UDEV
install -m 644 "$PROJECT_ROOT/conf/power/data/omaconf-keyboard-backlight.service" \
    "$PROJECT_ROOT/conf/power/data/omaconf-keyboard-backlight@.service" \
    "$PROJECT_ROOT/conf/power/data/omaconf-keyboard-backlight.timer" /etc/systemd/system/
chmod 644 /etc/udev/rules.d/99-omaconf-keyboard-backlight.rules \
    /etc/systemd/system/omaconf-keyboard-backlight.{service,timer} \
    /etc/systemd/system/omaconf-keyboard-backlight@.service
udevadm control --reload-rules
systemctl daemon-reload
systemctl enable omaconf-keyboard-backlight.service
systemctl restart omaconf-keyboard-backlight.service
systemctl enable --now omaconf-keyboard-backlight.timer

