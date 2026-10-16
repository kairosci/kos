#!/usr/bin/env bash
set -euo pipefail

_SESSION_MODULE="$PROJECT_DIR/modules/conf/session"
_SESSION_POLICY="$_SESSION_MODULE/data/policy.json"
install -d -m 755 /usr/local/lib/os/session/{data/locales,scripts,qml} /usr/local/lib/os/messages
install -m 755 "$_SESSION_MODULE/install.sh" /usr/local/lib/os/session/install.sh
for _session_directory in data scripts qml; do
    while IFS= read -r -d '' _session_file; do
        install -m 644 "$_session_file" "/usr/local/lib/os/session/$_session_directory/${_session_file#"$_SESSION_MODULE/$_session_directory/"}"
    done < <(find "$_SESSION_MODULE/$_session_directory" -type f -print0)
done
rm -f /usr/local/lib/os/session/data/clean.lua /usr/local/lib/os/session/data/runtime.lua /usr/local/lib/os/session/data/shell.jq
install -m 644 "$PROJECT_DIR/scripts/lib/i18n.sh" "$PROJECT_DIR/scripts/lib/userconf.sh" /usr/local/lib/os/
install -m 644 "$PROJECT_DIR"/scripts/lib/messages/*.msg /usr/local/lib/os/messages/

for user_home in /home/*; do
    [[ -d "$user_home" && -f "$user_home/.config/hypr/hyprland.lua" ]] || continue
    _session_user=${user_home##*/}
    if [[ "${SETUP_SCOPE:-full}" == session && "$_session_user" != "$PRIMARY_USER" ]]; then continue; fi
    _session_before=$(bash "$_SESSION_MODULE/scripts/fingerprint.sh" "$user_home" "$_SESSION_POLICY") || err "session.validation_failed" "$_session_user"
    _session_require_engine=0
    [[ "${SETUP_SCOPE:-full}" != session ]] || _session_require_engine=1
    user_as "$_session_user" env "OMARCHY_PATH=${OMARCHY_PATH:-/usr/share/omarchy}" "OS_SESSION_REQUIRE_ENGINE=$_session_require_engine" \
        bash "$_SESSION_MODULE/install.sh" || err "session.validation_failed" "$_session_user"
    if [[ -f "$user_home/.config/omarchy/hooks/post-update.d/99-os-persist" ]]; then
        user_as "$_session_user" bash -c '
            set -euo pipefail
            source "$1"
            install_user_file "$2" "$HOME/.config/omarchy/hooks/post-update.d/99-os-persist" 755
        ' bash "$PROJECT_DIR/scripts/lib/userconf.sh" "$PROJECT_DIR/hooks/post-update.d/99-os-persist" || err "session.validation_failed" "post-update hook"
    fi
    if [[ "${SETUP_SCOPE:-full}" == session ]]; then
        _session_runtime=$(jq -r '.runtime' "$user_home/.local/share/os/session/data/policy.json")
        user_as "$_session_user" systemctl --user set-environment "QS_CONFIG_PATH=$_session_runtime/shell" || err "session.validation_failed" "Quickshell environment"
        user_as "$_session_user" hyprctl reload config-only || err "session.validation_failed" Hyprland
        _session_errors=$(user_as "$_session_user" hyprctl configerrors) || err "session.validation_failed" Hyprland
        [[ -z "${_session_errors//[[:space:]]/}" ]] || err "session.validation_failed" "$_session_errors"
        _session_after=$(bash "$_SESSION_MODULE/scripts/fingerprint.sh" "$user_home" "$_SESSION_POLICY") || err "session.validation_failed" "$_session_user"
        _session_menu_id=$(jq -r '.menu.id' "$_SESSION_POLICY")
        if [[ "$_session_before" != "$_session_after" ]] \
            || ! _session_menu_status=$(omarchy_as "$_session_user" shell shell call "$_session_menu_id" status '{}') \
            || ! jq -e '.policyLoaded and .availableApps > 0 and .modelApps > 0' <<< "$_session_menu_status" > /dev/null; then
            omarchy_as "$_session_user" restart shell || err "session.validation_failed" Quickshell
        fi
        omarchy_as "$_session_user" shell shell ping || err "session.validation_failed" Quickshell
        _session_menu_ready=0
        for _session_attempt in {1..50}; do
            if _session_menu_status=$(omarchy_as "$_session_user" shell shell call "$_session_menu_id" status '{}') \
                && jq -e '.policyLoaded and .availableApps > 0 and .modelApps > 0 and (.menus | index("apps") != null and index("learn") == null and index("bar") == null)' <<< "$_session_menu_status" > /dev/null; then
                _session_menu_ready=1
                break
            fi
            sleep 0.1
        done
        [[ "$_session_menu_ready" == 1 ]] || { printf '%s\n' "$_session_menu_status"; err "session.validation_failed" "OS menu Apps"; }
        _session_controls=$(omarchy_as "$_session_user" shell os.controls status) || err "session.validation_failed" "OS controls"
        jq -e '.barSurface == false and .barSize == 0' <<< "$_session_controls" > /dev/null || err "session.validation_failed" "bar surface"
        while IFS= read -r _session_panel; do
            _session_panel_state=$(omarchy_as "$_session_user" shell shell call "$_session_panel" status '{}') || err "session.validation_failed" "$_session_panel"
            jq -e --arg id "$_session_panel" '.ready and .id == $id' <<< "$_session_panel_state" > /dev/null || err "session.validation_failed" "$_session_panel"
        done < <(jq -r '.panels[].id' "$_SESSION_POLICY")
        _session_stamp="$user_home/.local/state/os/session/runtime-verified.sha256"
        if [[ ! -f "$_session_stamp" ]] || [[ "$(cat "$_session_stamp")" != "$_session_after" ]]; then
            for _session_route in root apps; do
                omarchy_as "$_session_user" menu summon "$_session_route" || err "session.validation_failed" "$_session_route menu"
                _session_popup_ready=0
                for _session_attempt in {1..20}; do
                    _session_menu_status=$(omarchy_as "$_session_user" shell shell call "$_session_menu_id" status '{}') || err "session.validation_failed" "$_session_route menu"
                    if jq -e --arg route "$_session_route" '.route == $route and .renderedWidth > 0 and .modelApps > 0' <<< "$_session_menu_status" > /dev/null; then
                        _session_popup_ready=1
                        break
                    fi
                    sleep 0.1
                done
                omarchy_as "$_session_user" menu close || err "session.validation_failed" "menu close"
                [[ "$_session_popup_ready" == 1 ]] || err "session.validation_failed" "$_session_route menu geometry"
            done
            while IFS= read -r _session_panel; do
                omarchy_as "$_session_user" shell shell summon "$_session_panel" '{}' || err "session.validation_failed" "$_session_panel"
                _session_popup_ready=0
                for _session_attempt in {1..20}; do
                    _session_layers=$(user_as "$_session_user" hyprctl layers -j) || err "session.validation_failed" layers
                    if jq -e '[.[] | .levels[][]? | select(.namespace == "os-control")] | length > 0' <<< "$_session_layers" > /dev/null; then
                        _session_popup_ready=1
                        break
                    fi
                    sleep 0.1
                done
                omarchy_as "$_session_user" shell shell hide "$_session_panel" || err "session.validation_failed" "$_session_panel"
                [[ "$_session_popup_ready" == 1 ]] || err "session.validation_failed" "$_session_panel popup"
                _session_panel_state=$(omarchy_as "$_session_user" shell shell call "$_session_panel" status '{}') || err "session.validation_failed" "$_session_panel"
                jq -e '.opened == false' <<< "$_session_panel_state" > /dev/null || err "session.validation_failed" "$_session_panel close"
            done < <(jq -r '.panels[].id' "$_SESSION_POLICY")
            printf '%s\n' "$_session_after" | user_as "$_session_user" bash -c '
                set -euo pipefail
                source "$1"
                install_user_content "$2" 600
            ' bash "$PROJECT_DIR/scripts/lib/userconf.sh" "$_session_stamp" || err "session.validation_failed" "runtime state"
        fi
        _session_default=$(user_as "$_session_user" env "QS_CONFIG_PATH=$_session_runtime/shell" qs ipc call shell ping) || err "session.validation_failed" "Quickshell default"
        [[ "$_session_default" == ok ]] || err "session.validation_failed" "Quickshell default"
    fi
done
