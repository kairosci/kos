#!/usr/bin/env bash
set -euo pipefail

install -d -m 755 /usr/local/lib/os/session/data /usr/local/lib/os/messages
install -m 755 "$PROJECT_DIR/modules/conf/session/install.sh" /usr/local/lib/os/session/install.sh
install -m 644 "$PROJECT_DIR"/modules/conf/session/data/* /usr/local/lib/os/session/data/
install -m 644 "$PROJECT_DIR/scripts/lib/i18n.sh" "$PROJECT_DIR/scripts/lib/userconf.sh" /usr/local/lib/os/
install -m 644 "$PROJECT_DIR"/scripts/lib/messages/*.msg /usr/local/lib/os/messages/

for user_home in /home/*; do
    [[ -d "$user_home" && -f "$user_home/.config/hypr/hyprland.lua" ]] || continue
    _session_user=${user_home##*/}
    if [[ "${SETUP_SCOPE:-full}" == session && "$_session_user" != "$PRIMARY_USER" ]]; then
        continue
    fi
    _session_files=(
        "$user_home/.config/omarchy/plugins/os.menu/Menu.qml"
        "$user_home/.config/omarchy/plugins/os.menu/MenuModel.js"
        "$user_home/.config/omarchy/plugins/os.menu/manifest.json"
        "$user_home/.config/omarchy/extensions/os-menu.json"
        "$user_home/.config/omarchy/shell.json"
    )
    _session_before=""
    _session_files_exist=1
    for _session_file in "${_session_files[@]}"; do
        [[ -f "$_session_file" ]] || _session_files_exist=0
    done
    if [[ "$_session_files_exist" == 1 ]]; then
        _session_before=$(sha256sum "${_session_files[@]}")
    fi
    user_as "$_session_user" env "OMARCHY_PATH=${OMARCHY_PATH:-/usr/share/omarchy}" \
        bash "$PROJECT_DIR/modules/conf/session/install.sh" || err "session.validation_failed" "$_session_user"
    if [[ -f "$user_home/.config/omarchy/hooks/post-update.d/99-os-persist" ]]; then
        user_as "$_session_user" bash -c '
            set -euo pipefail
            source "$1"
            install_user_file "$2" "$HOME/.config/omarchy/hooks/post-update.d/99-os-persist" 755
        ' bash "$PROJECT_DIR/scripts/lib/userconf.sh" "$PROJECT_DIR/hooks/post-update.d/99-os-persist" || err "session.validation_failed" "post-update hook"
    fi
    if [[ "${SETUP_SCOPE:-full}" == session ]]; then
        user_as "$_session_user" hyprctl reload config-only || err "session.validation_failed" Hyprland
        _session_errors=$(user_as "$_session_user" hyprctl configerrors) || err "session.validation_failed" Hyprland
        [[ -z "${_session_errors//[[:space:]]/}" ]] || err "session.validation_failed" "$_session_errors"
        _session_after=$(sha256sum "${_session_files[@]}")
        if [[ "$_session_before" != "$_session_after" ]] \
            || ! _session_menu_status=$(omarchy_as "$_session_user" shell shell call omarchy.menu ping '{}') \
            || [[ "$_session_menu_status" != ok ]]; then
            omarchy_as "$_session_user" restart shell || err "session.validation_failed" Quickshell
        fi
        omarchy_as "$_session_user" shell shell ping || err "session.validation_failed" Quickshell
        _session_menu_ready=0
        for _session_attempt in {1..50}; do
            if _session_menu_status=$(omarchy_as "$_session_user" shell shell call omarchy.menu ping '{}') && [[ "$_session_menu_status" == ok ]]; then
                _session_menu_ready=1
                break
            fi
            sleep 0.1
        done
        [[ "$_session_menu_ready" == 1 ]] || err "session.validation_failed" "OS menu"
    fi
done
