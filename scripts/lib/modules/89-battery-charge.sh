#!/usr/bin/env bash

set -euo pipefail

log "power.charge"
mkdir -p /etc/omaconf
chmod 755 /etc/omaconf 2>/dev/null || warn "power.omaconf_chmod"
printf '%s\n' 'BATTERY_CHARGE_LIMIT=75' > /etc/omaconf/power.conf
chmod 644 /etc/omaconf/power.conf

# shellcheck source=scripts/lib/battery-driver.sh
source "$PROJECT_ROOT/scripts/lib/battery-driver.sh"
if battery_driver_needs_recovery; then
    log "power.samsung_recover"
    battery_driver_recover || err "power.samsung_reload_failed"
fi

cat > /etc/udev/rules.d/98-battery-charge-threshold.rules << 'UDEV'
ACTION=="add|change", SUBSYSTEM=="power_supply", ATTR{type}=="Battery", RUN+="/usr/local/libexec/omaconf-set-battery-charge-limit"
UDEV
chmod 644 /etc/udev/rules.d/98-battery-charge-threshold.rules
install -Dm755 "$PROJECT_ROOT/scripts/lib/set-battery-charge-limit.sh" /usr/local/libexec/omaconf-set-battery-charge-limit
install -Dm644 "$PROJECT_ROOT/scripts/lib/battery-driver.sh" /usr/local/libexec/omaconf-battery-driver.sh
install -Dm755 "$PROJECT_ROOT/scripts/lib/battery-charge-resume.sh" /usr/lib/systemd/system-sleep/omaconf-battery-charge-limit
udevadm control --reload-rules 2>/dev/null || warn "power.udev_reload_skipped"

_udev_triggered=0
_udev_attempted=0
for _battery in /sys/class/power_supply/*; do
    [[ -e "$_battery" ]] || continue
    [[ -r "$_battery/type" && $(cat "$_battery/type") == Battery ]] || continue
    _udev_attempted=$((_udev_attempted + 1))
    if udevadm trigger --subsystem-match=power_supply \
        --sysname-match="${_battery##*/}"; then
        _udev_triggered=$((_udev_triggered + 1))
    else
        warn "power.udev_trigger_node_skipped" "$(basename "$_battery")"
    fi
done
if [[ $_udev_attempted -gt 0 && $_udev_triggered -eq 0 ]]; then
    warn "power.udev_trigger_skipped"
fi
unset _battery _udev_triggered _udev_attempted

mkdir -p /etc/tmpfiles.d
cat > /etc/tmpfiles.d/battery-charge-threshold.conf << 'TMPFILES'
d /run/omaconf 0755 root root -
TMPFILES
chmod 644 /etc/tmpfiles.d/battery-charge-threshold.conf
systemd-tmpfiles --create /etc/tmpfiles.d/battery-charge-threshold.conf 2>/dev/null || warn "power.tmpfiles_skipped"

cat > /etc/systemd/system/battery-charge-threshold.service << 'SERVICE'
[Unit]
Description=Universal Battery Charge Threshold Policy
After=systemd-udev-trigger.service

[Service]
Type=oneshot
ExecStart=/usr/local/libexec/omaconf-set-battery-charge-limit
TimeoutStartSec=30
NoNewPrivileges=yes
ProtectHome=yes
ProtectSystem=strict
ReadWritePaths=/run/omaconf /sys/devices

[Install]
WantedBy=multi-user.target
SERVICE
chmod 644 /etc/systemd/system/battery-charge-threshold.service
systemctl daemon-reload 2>/dev/null || warn "power.daemon_reload_skipped"
systemctl enable battery-charge-threshold.service 2>/dev/null || warn "power.charge_enable_skipped"
systemctl restart battery-charge-threshold.service || warn "power.charge_start_skipped"

cat > /etc/systemd/system/battery-charge-threshold.timer << 'TIMER'
[Unit]
Description=Reconcile battery charge threshold

[Timer]
OnBootSec=30s
OnUnitInactiveSec=60s

[Install]
WantedBy=timers.target
TIMER
chmod 644 /etc/systemd/system/battery-charge-threshold.timer
systemctl daemon-reload
systemctl enable --now battery-charge-threshold.timer

battery_query() {
    local key="$1" value=""
    value=$(/usr/local/libexec/omaconf-set-battery-charge-limit --query "$key" 2>/dev/null) || value=""
    printf '%s' "$value"
}

BATTERY_POLICY=$(battery_query limit)
[[ "$BATTERY_POLICY" =~ ^[0-9]+$ ]] || BATTERY_POLICY=$(sed -n 's/^BATTERY_CHARGE_LIMIT=\([0-9][0-9]*\)$/\1/p' /etc/omaconf/power.conf | head -1)
BATTERY_LIMIT="${BATTERY_POLICY}%"

if ! /usr/local/libexec/omaconf-set-battery-charge-limit; then
    warn "power.charge_write_rejected" "$BATTERY_LIMIT"
fi

case "$(battery_query enforced)" in
    yes)
        log "power.charge_enforced" "$BATTERY_LIMIT"
        ;;
    no)
        if [[ "$(battery_query functional_nodes)" == "0" && "$(battery_query drift)" == no ]]; then
            warn "power.charge_unsupported" "$BATTERY_LIMIT"
        fi
        ;;
esac
