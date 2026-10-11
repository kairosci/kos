#!/usr/bin/env bash

set -euo pipefail

log "power.suspend_resume"

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

rm -f /etc/systemd/sleep.conf.d/99-omaconf-deep-sleep.conf

target_sleep_mode=""
if [[ -r /sys/power/mem_sleep ]]; then
    if grep -q '\[deep\]' /sys/power/mem_sleep; then
        target_sleep_mode="deep"
    elif grep -q '\[s2idle\]' /sys/power/mem_sleep; then
        target_sleep_mode="s2idle"
    elif grep -qw deep /sys/power/mem_sleep; then
        target_sleep_mode="s2idle"
    fi
fi

if [[ -n "$target_sleep_mode" ]]; then
    log "power.suspend_mode" "$target_sleep_mode"
    mkdir -p /etc/systemd/sleep.conf.d
    chmod 755 /etc/systemd/sleep.conf.d
    cat > /etc/systemd/sleep.conf.d/99-omaconf-suspend.conf << SLEEP_CONF
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
AllowHybridSleep=yes
MemorySleepMode=$target_sleep_mode
SLEEP_CONF
    chmod 644 /etc/systemd/sleep.conf.d/99-omaconf-suspend.conf
fi

if lsmod 2>/dev/null | grep -qw nvidia || pacman -Q nvidia &>/dev/null || pacman -Q nvidia-open &>/dev/null || pacman -Q nvidia-dkms &>/dev/null; then
    log "power.nvidia_suspend"
    mkdir -p /etc/modprobe.d
    cat > /etc/modprobe.d/nvidia-power-management.conf << 'NVIDIA_CONF'
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp
NVIDIA_CONF
    chmod 644 /etc/modprobe.d/nvidia-power-management.conf

    for svc in nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service; do
        if systemctl list-unit-files "$svc" &>/dev/null; then
            systemctl enable "$svc" 2>/dev/null || warn "power.daemon_reload_skipped"
        fi
    done
fi

systemctl daemon-reload 2>/dev/null || warn "power.daemon_reload_skipped"
