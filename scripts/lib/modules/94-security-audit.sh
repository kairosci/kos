#!/usr/bin/env bash

Os::scripts::lib::modules::94_security_audit_sh::run() {

set -euo pipefail

log "maint.weekly"
mkdir -p /etc/cron.weekly
cat > /etc/cron.weekly/security-audit.sh << 'AUDITEOF'
#!/usr/bin/env bash
set -euo pipefail
failures=()
if /usr/bin/lynis --cron system >> /var/log/lynis-audit.log 2>&1; then
    :
else
    failures+=(lynis)
fi
if /usr/bin/rkhunter --check --skip-keypress --report-warnings-only >> /var/log/rkhunter-audit.log 2>&1; then
    :
else
    failures+=(rkhunter)
fi
if /usr/bin/clamdscan --fdpass --multiscan --infected --log=/var/log/clamav/os-scan.log /home /root /etc /usr /opt /var /boot; then
    :
else
    failures+=(clamav)
fi
arch_report=$(mktemp)
if /usr/bin/arch-audit --show-cve --format '%n %v %s %c' > /var/log/arch-audit.log 2>&1 &&
    /usr/bin/arch-audit --quiet --show-cve > "$arch_report" 2>> /var/log/arch-audit.log; then
    if [[ -s $arch_report ]]; then
        failures+=(arch-audit-review)
        cat "$arch_report" >> /var/log/arch-audit.log
    fi
else
    failures+=(arch-audit-unavailable)
fi
rm -f "$arch_report"
if ((${#failures[@]} > 0)); then
    printf 'Security audit checks reported findings or errors: %s\n' "${failures[*]}" >&2
    exit 1
fi
AUDITEOF
chmod 755 /etc/cron.weekly/security-audit.sh
cat > /etc/systemd/system/os-security-audit.service << 'SERVICE'
[Unit]
Description=OS security audit

[Service]
Type=oneshot
ExecStart=/etc/cron.weekly/security-audit.sh
Nice=19
IOSchedulingClass=idle
SERVICE
cat > /etc/systemd/system/os-security-audit.timer << 'TIMER'
[Unit]
Description=Weekly OS security audit

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
TIMER
chmod 644 /etc/systemd/system/os-security-audit.{service,timer}
cat > /etc/logrotate.d/os-security-audit << 'LOGROTATE'
/var/log/lynis-audit.log /var/log/rkhunter-audit.log /var/log/arch-audit.log /var/log/clamav/os-scan.log {
    weekly
    rotate 12
    compress
    missingok
    notifempty
    create 640 root root
}
LOGROTATE
systemctl daemon-reload
if systemctl is-enabled --quiet cronie.service || systemctl is-active --quiet cronie.service; then
    systemctl enable --now cronie.service
    systemctl disable --now os-security-audit.timer
else
    systemctl enable --now os-security-audit.timer
fi

}

Os::scripts::lib::modules::94_security_audit_sh::run "$@"
