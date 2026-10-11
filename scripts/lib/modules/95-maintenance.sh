#!/usr/bin/env bash

set -euo pipefail

log "maint.pacman_security"
mkdir -p /etc/pacman.d/hooks
if [[ -f /etc/pacman.d/hooks/99-verify-inserted-keyrings.hook ]] &&
    grep -qx 'Exec = /usr/bin/pacman-key --verify' /etc/pacman.d/hooks/99-verify-inserted-keyrings.hook; then
    rm -f /etc/pacman.d/hooks/99-verify-inserted-keyrings.hook
fi

log "maint.weekly"
mkdir -p /etc/cron.weekly
cat > /etc/cron.weekly/security-audit.sh << 'AUDITEOF'
#!/usr/bin/env bash
set -euo pipefail
/usr/bin/lynis --cron system >> /var/log/lynis-audit.log 2>&1
/usr/bin/rkhunter --check --skip-keypress --report-warnings-only >> /var/log/rkhunter-audit.log 2>&1
AUDITEOF
chmod 755 /etc/cron.weekly/security-audit.sh
cat > /etc/systemd/system/kos-security-audit.service << 'SERVICE'
[Unit]
Description=Kos security audit

[Service]
Type=oneshot
ExecStart=/etc/cron.weekly/security-audit.sh
Nice=19
IOSchedulingClass=idle
SERVICE
cat > /etc/systemd/system/kos-security-audit.timer << 'TIMER'
[Unit]
Description=Weekly Kos security audit

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
TIMER
chmod 644 /etc/systemd/system/kos-security-audit.{service,timer}
systemctl daemon-reload
if systemctl is-enabled --quiet cronie.service || systemctl is-active --quiet cronie.service; then
    systemctl enable --now cronie.service
    systemctl disable --now kos-security-audit.timer
else
    systemctl enable --now kos-security-audit.timer
fi

log "maint.logs"
cat > /etc/logrotate.d/security << 'LOGROTATE'
/var/log/sudo-io/*
{
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    create 640 root adm
    sharedscripts
    postrotate
        /usr/bin/systemctl kill -s HUP systemd-journald 2>/dev/null
    endscript
}
LOGROTATE

log "maint.sudo"
mkdir -p /var/log/sudo
cat > /etc/sudoers.d/security << 'SUDO'
Defaults env_reset,timestamp_timeout=5,passwd_timeout=2
Defaults mail_badpass
Defaults use_pty
Defaults log_input,log_output
Defaults iolog_dir=/var/log/sudo
SUDO
visudo -cf /etc/sudoers.d/security >/dev/null 2>&1 || { rm -f /etc/sudoers.d/security; err "maint.sudoers_invalid"; }
chmod 440 /etc/sudoers.d/security

echo 'Defaults passwd_tries=3' > /etc/sudoers.d/passwd-tries
chmod 440 /etc/sudoers.d/passwd-tries

log "maint.tpm"
if [[ -f /usr/lib/nvpcr/verity.nvpcr ]]; then
    rm -f /usr/lib/nvpcr/verity.nvpcr
fi

log "maint.voxtype"
if ! command -v voxtype &>/dev/null; then
    for u_home in /home/*; do
        [[ -d "$u_home" ]] || continue
        rm -f "$u_home/.config/systemd/user/graphical-session.target.wants/voxtype.service" 2>/dev/null || warn "maint.voxtype_user_skipped" "$u_home"
    done
    if systemctl list-unit-files voxtype.service &>/dev/null; then
        systemctl --global disable voxtype.service 2>/dev/null || warn "maint.voxtype_global_skipped"
    fi
fi

log "maint.profiles"
for u_home in /home/*; do
    [[ -d "$u_home" ]] || continue
    if [[ -f "$u_home/.profile" ]]; then
        sed -i 's|^\. "\$HOME/\.cargo/env"|[ -f "$HOME/.cargo/env" ] \&\& . "$HOME/.cargo/env"|' "$u_home/.profile"
        sed -i 's|^source "\$HOME/\.cargo/env"|[ -f "$HOME/.cargo/env" ] \&\& source "$HOME/.cargo/env"|' "$u_home/.profile"
    fi
    if [[ -f "$u_home/.bash_profile" ]]; then
        sed -i 's|^\. "\$HOME/\.cargo/env"|[[ -f "$HOME/.cargo/env" ]] \&\& . "$HOME/.cargo/env"|' "$u_home/.bash_profile"
        sed -i 's|^source "\$HOME/\.cargo/env"|[[ -f "$HOME/.cargo/env" ]] \&\& source "$HOME/.cargo/env"|' "$u_home/.bash_profile"
    fi
done

log "maint.orphans"
orphans=()
if pacman -Qdtq &>/dev/null; then
    mapfile -t orphans < <(pacman -Qdtq)
fi
if [[ ${#orphans[@]} -gt 0 && -n "${orphans[0]}" ]]; then
    pacman -Rns --noconfirm "${orphans[@]}" 2>/dev/null || warn "maint.orphans_skipped"
fi

log "maint.cache"
if command -v paccache >/dev/null; then
    paccache -rk2 || warn "maint.cache_skipped"
else
    warn "maint.cache_skipped"
fi
