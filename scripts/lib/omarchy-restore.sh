#!/usr/bin/env bash

Os::scripts::lib::omarchy_restore_sh::run() {

omarchy_restore_user() {
    local user="$1" home="$2" upstream="${OMARCHY_PATH:-/usr/share/omarchy}"
    local bashrc="${OS_RESTORE_BASHRC:-/etc/skel/.bashrc}"
    local backup="${OS_RESTORE_BACKUP_ROOT:-/var/lib/os/omarchy-restore}/$user" directory file
    [[ "$user" =~ ^[a-z_][a-z0-9_-]*\$?$ && -d "$home" && ! -L "$home" ]] || return 1
    [[ -r "$upstream/config/hypr/hyprland.lua" && -r "$upstream/config/omarchy/shell.json" && -r "$bashrc" ]] || return 1
    [[ ! -f "$backup/done" ]] || return 0
    [[ ! -L "$home/.bashrc" && ! -L "$home/.bashrc.bak" ]] || return 1
    log "restore.start" "$user"
    install -d -m 700 "$backup" || return 1
    for directory in .config/hypr .config/omarchy .config/os .local/state/omarchy; do
        [[ ! -L "$home/$directory" ]] || return 1
        if [[ -d "$home/$directory" && ! -e "$backup/$directory" ]]; then
            install -d -m 700 "$backup/${directory%/*}" || return 1
            cp -a "$home/$directory" "$backup/$directory" || return 1
        fi
    done
    for file in .bashrc .bashrc.bak; do
        if [[ -f "$home/$file" ]]; then
            if [[ ! -e "$backup/$file" ]]; then
                cp -a "$home/$file" "$backup/$file" || return 1
            fi
            chown "$user:$user" "$home/$file" || return 1
        fi
    done
    install -d -m 755 -o "$user" -g "$user" "$home/.config" || return 1
    for directory in hypr omarchy; do
        cp -a "$upstream/config/$directory" "$home/.config/" || return 1
        chown -R --no-dereference "$user:$user" "$home/.config/$directory" || return 1
    done
    if [[ -d "$home/.local/state/omarchy" ]]; then
        chown -R --no-dereference "$user:$user" "$home/.local/state/omarchy" || return 1
    fi
    user_as "$user" bash -c 'source "$1"; install_user_file "$2" "$HOME/.bashrc"' bash "$PROJECT_DIR/scripts/lib/userconf.sh" "$bashrc" || return 1
    install -m 600 /dev/null "$backup/done" || return 1
    log "restore.done" "$backup"
}

}

Os::scripts::lib::omarchy_restore_sh::run "$@"
