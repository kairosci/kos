#!/usr/bin/env bash
set -euo pipefail
[[ -r "$PROJECT_DIR/conf/kos/data/migration-packages.list" && -r "$PROJECT_DIR/conf/kos/data/legacy-automation" ]] || return 0
source "$PROJECT_DIR/scripts/lib/migration.sh"
_legacy_desktop=$(head -n 1 "$PROJECT_DIR/conf/kos/data/migration-packages.list")
_legacy_automation=$(cat "$PROJECT_DIR/conf/kos/data/legacy-automation")
[[ "$_legacy_desktop" =~ ^[a-z]+$ && "$_legacy_automation" =~ ^[a-z]+$ ]] || err release.invalid
install -d -m 700 /var/lib/kos/migration
_migration_backup=$(mktemp -d /var/lib/kos/migration/apply.XXXXXX)
cp -a /etc/pacman.conf "$_migration_backup/pacman.conf"
if [[ -f /etc/pacman.d/mirrorlist ]]; then
    cp -a /etc/pacman.d/mirrorlist "$_migration_backup/mirrorlist"
fi
kos_migrate_pacman /etc/pacman.conf /etc/pacman.d/mirrorlist "$_legacy_desktop" || err release.invalid
for _home in /home/*; do
    [[ -d "$_home" && ! -L "$_home" ]] || continue
    _user=$(basename "$_home")
    id "$_user" >/dev/null || err release.invalid
    kos_migrate_home "$_home" "$_migration_backup/users/$_user" "$_legacy_desktop" "$_legacy_automation" || err release.invalid
    for _directory in .config/kos .local/state/kos .cache/kos; do
        [[ ! -d "$_home/$_directory" ]] || chown -R "$_user:$_user" "$_home/$_directory"
    done
    if [[ -f "$_home/.config/hypr/hyprland.lua" ]]; then
        user_as "$_user" env KOS_PATH=/usr/share/kos Hyprland --verify-config --config "$_home/.config/hypr/hyprland.lua"
    fi
done
for _unit in /etc/systemd/system/"$_legacy_automation"-*.service /etc/systemd/system/"$_legacy_automation"-*.timer; do
    [[ -f "$_unit" ]] || continue
    systemctl disable --now "${_unit##*/}"
    install -d -m 700 "$_migration_backup/units"
    mv "$_unit" "$_migration_backup/units/"
done
systemctl daemon-reload
for _directory in "/etc/$_legacy_automation" "/usr/local/lib/$_legacy_automation"; do
    [[ -e "$_directory" ]] || continue
    install -d -m 700 "$_migration_backup/system${_directory%/*}"
    mv "$_directory" "$_migration_backup/system$_directory"
done
for _file in /usr/local/libexec/"$_legacy_automation"-* /usr/lib/systemd/system-sleep/"$_legacy_automation"-* /etc/pacman.d/hooks/*"$_legacy_automation"*; do
    [[ -f "$_file" ]] || continue
    install -d -m 700 "$_migration_backup/system${_file%/*}"
    mv "$_file" "$_migration_backup/system$_file"
done
