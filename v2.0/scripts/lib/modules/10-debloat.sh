#!/usr/bin/env bash

set -euo pipefail

log "debloat.start"
log "debloat.pin"
"$PROJECT_DIR/script/os-lua" apply-debloat || err "debloat.partial_removal"

log "debloat.foot_cleanup"
if ! pacman -Q foot &>/dev/null && ! command -v foot &>/dev/null; then
    for u_home in /home/*; do
        [[ -d "$u_home" ]] || continue
        rm -f "$u_home/.local/share/applications/foot.desktop" 2>/dev/null || warn "debloat.foot_skipped" "$u_home"
        rm -f "$u_home/.local/share/applications/footclient.desktop" 2>/dev/null || warn "debloat.footclient_skipped" "$u_home"
        rm -f "$u_home/.local/share/applications/foot-server.desktop" 2>/dev/null || warn "debloat.footserver_skipped" "$u_home"
    done
fi

log "debloat.webapps"
# shellcheck source=../userconf.sh
source "$PROJECT_DIR/scripts/lib/userconf.sh"
source "$PROJECT_DIR/scripts/lib/retired-config.sh"
for u_home in /home/*; do
    [[ -d "$u_home" ]] || continue
    rm -f "$u_home/.local/bin/geany-project" "$u_home/.local/bin/tode" \
        "$u_home/.local/share/applications/geany-project.desktop" \
        "$u_home/.local/share/applications/geany.desktop" \
        "$u_home/.config/geany/colorschemes/os.conf"
    for _retired_config in "$u_home/.config/geany" "$u_home/.config/tode" "$u_home/.local/share/tode"; do
        [[ -d "$_retired_config" ]] || continue
        _retired_user=$(basename "$u_home")
        _retired_root="$u_home/.local/state/omarchy/retired"
        install -d -m 700 -o "$_retired_user" -g "$_retired_user" "$_retired_root"
        _retired_backup=$(mktemp -d "$_retired_root/$(basename "$_retired_config").XXXXXX")
        mv "$_retired_config" "$_retired_backup/config"
        chown -R "$_retired_user:$_retired_user" "$_retired_backup"
    done
    rm -rf "$u_home/.local/lib/tode"
    if [[ -f "$u_home/.bashrc" ]] && grep -qE '^# >>> om(ablot|aconf) yazi >>>$' "$u_home/.bashrc"; then
        _yazi_rc=$(mktemp)
        awk '
            /^# >>> om(ablot|aconf) yazi >>>$/ { skip=1; next }
            /^# <<< om(ablot|aconf) yazi <<<$/{ skip=0; next }
            !skip { print }
            END { if (skip) exit 1 }
        ' "$u_home/.bashrc" > "$_yazi_rc" || err "defaults.app_failed" "yazi shell migration"
        install_user_content "$u_home/.bashrc" "$(stat -c %a "$u_home/.bashrc")" < "$_yazi_rc"
        rm -f "$_yazi_rc"
        chown "$(basename "$u_home"):$(basename "$u_home")" "$u_home/.bashrc"
    fi
done
for webapp in Basecamp "Google Contacts" "Google Maps" "Google Messages" "Google Photos" Discord HEY WhatsApp X YouTube Zoom; do
    rm -f "/usr/share/omarchy/applications/$webapp.desktop"
done
if [[ -d /usr/share/omarchy/applications ]]; then
    if app_matches=$(grep -rlE 'omarchy-(launch-webapp|webapp-handler)' /usr/share/omarchy/applications 2>/dev/null); then
        while IFS= read -r app_file; do
            [[ -f "$app_file" ]] && rm -f "$app_file"
        done <<< "$app_matches"
    fi
fi
for u_home in /home/*; do
    [[ -d "$u_home" ]] || continue
    for webapp in Basecamp "Google Contacts" "Google Maps" "Google Messages" "Google Photos" Discord HEY WhatsApp X YouTube Zoom; do
        rm -f "$u_home/.local/share/applications/$webapp.desktop"
    done
    if [[ -d "$u_home/.local/share/applications" ]]; then
        if user_matches=$(grep -rlE 'omarchy-(launch-webapp|webapp-handler)' "$u_home/.local/share/applications" 2>/dev/null); then
            while IFS= read -r app_file; do
                [[ -f "$app_file" ]] && rm -f "$app_file"
            done <<< "$user_matches"
        fi
    fi
done

log "debloat.webapps_hook"
for u_home in /home/*; do
    [[ -d "$u_home" ]] || continue
    _u=$(basename "$u_home")
    for hook_kind in pre-refresh-pacman.d post-update.d; do
        mkdir -p "$u_home/.config/os/hooks/$hook_kind"
        if [[ -f "$PROJECT_DIR/hooks/$hook_kind/99-os-persist" ]]; then
            cp "$PROJECT_DIR/hooks/$hook_kind/99-os-persist" "$u_home/.config/os/hooks/$hook_kind/99-os-persist"
            chmod +x "$u_home/.config/os/hooks/$hook_kind/99-os-persist"
            chown "$_u":"$_u" "$u_home/.config/os/hooks/$hook_kind/99-os-persist" 2>/dev/null || warn "debloat.hook_chown_failed" "$_u"
        fi
    done
done

log "desktop.sweep"
if [[ -f "$PROJECT_DIR/scripts/lib/desktop-cleanup.sh" ]]; then
    # shellcheck source=../desktop-cleanup.sh
    source "$PROJECT_DIR/scripts/lib/desktop-cleanup.sh"
    desktop_cleanup_sweep || warn "desktop.refresh_skipped"
fi
