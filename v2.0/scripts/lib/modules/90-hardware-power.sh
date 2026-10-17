#!/usr/bin/env bash

set -euo pipefail

log "power.usb_storage"
log "power.protocols"
log "power.firewire"
log "power.filesystems"
log "power.perms"
"$PROJECT_ROOT/script/os-lua" apply-security-baseline || err "power.baseline_failed"
for u_home in /home/*; do
    [[ -d "$u_home" ]] || continue
    "$PROJECT_ROOT/script/os-lua" secure-home "$u_home" 2>/dev/null || warn "power.home_chown" "$u_home"
    for d in Documents Downloads Desktop; do
        [[ -d "$u_home/$d" ]] && (chmod 750 "$u_home/$d" 2>/dev/null || warn "power.user_dir_chown" "$u_home" "$d")
    done
done

log "power.shared_mem"
grep -q '^tmpfs /run/shm tmpfs' /etc/fstab || \
    echo "tmpfs /run/shm tmpfs defaults,nosuid,nodev,mode=1777 0 0" >> /etc/fstab

log "power.tmp"
for mount_point in /tmp /var/tmp; do
    if grep -q "^tmpfs $mount_point tmpfs" /etc/fstab; then
        if grep -q "^tmpfs $mount_point tmpfs.*noexec" /etc/fstab; then
            sed -i "s|^tmpfs $mount_point tmpfs.*|tmpfs $mount_point tmpfs defaults,nosuid,nodev,mode=1777 0 0|" /etc/fstab
        fi
    else
        echo "tmpfs $mount_point tmpfs defaults,nosuid,nodev,mode=1777 0 0" >> /etc/fstab
    fi
done

log "power.umask"
cat > /etc/profile.d/umask.sh << 'UMASK'
umask 077
UMASK
chmod 644 /etc/profile.d/umask.sh
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/99-umask.conf << 'SYSTEMD_UMASK'
[Manager]
UMask=077
SYSTEMD_UMASK

log "power.coredump"
cat > /etc/systemd/coredump.conf << 'COREDUMP'
[Coredump]
Storage=none
ProcessSizeMax=0
COREDUMP
systemctl daemon-reexec 2>/dev/null || warn "power.daemon_reexec_skipped"

log "power.networkmanager"
rm -f /etc/NetworkManager/conf.d/security.conf
