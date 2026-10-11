#!/usr/bin/env bash
set -euo pipefail

log "performance.install"
[[ -r /sys/fs/cgroup/cgroup.controllers && -r /proc/pressure/memory ]] || err "performance.unsupported"

_performance_data="$PROJECT_ROOT/conf/performance/data"
_oomd_changed=0
cmp -s "$_performance_data/oomd.conf" /etc/systemd/oomd.conf.d/90-omaconf.conf || _oomd_changed=1
install -Dm644 "$_performance_data/oomd.conf" /etc/systemd/oomd.conf.d/90-omaconf.conf
for _slice in app background session; do
    install -Dm644 "$_performance_data/$_slice.slice.conf" "/etc/systemd/user/$_slice.slice.d/90-omaconf.conf"
done
for _slice in user user-; do
    install -Dm644 "$_performance_data/memory.slice.conf" "/etc/systemd/system/$_slice.slice.d/90-omaconf-memory.conf"
done
install -Dm644 "$_performance_data/memory.slice.conf" /etc/systemd/user/session.slice.d/90-omaconf-memory.conf
install -d -m755 /etc/systemd/system/user@.service.d
sed 's/^\[Slice\]$/[Service]/' "$_performance_data/memory.slice.conf" > /etc/systemd/system/user@.service.d/90-omaconf-memory.conf
chmod 644 /etc/systemd/system/user@.service.d/90-omaconf-memory.conf

systemctl daemon-reload
systemctl enable --now systemd-oomd.socket systemd-oomd.service
if [[ "$_oomd_changed" == 1 ]]; then
    systemctl restart systemd-oomd.service
fi

for _home in /home/*; do
    [[ -d "$_home" ]] || continue
    _user=$(basename "$_home")
    _uid=$(id -u "$_user") || err "performance.user_failed" "$_user"
    if [[ -S "/run/user/$_uid/bus" ]]; then
        user_as "$_user" systemctl --user daemon-reload || err "performance.user_failed" "$_user"
    else
        log "performance.session_deferred" "$_user"
    fi
done
unset _performance_data _oomd_changed _slice _home _user _uid
