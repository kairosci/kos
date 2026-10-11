#!/usr/bin/env bash

set -euo pipefail

install -d -m 755 -o root -g root /usr/local/lib/omaconf/messages /etc/pacman.d/hooks
install -m 644 -o root -g root "$PROJECT_DIR/scripts/lib/i18n.sh" \
    "$PROJECT_DIR/scripts/lib/theme-preview.sh" \
    "$PROJECT_DIR/scripts/lib/desktop-workflow.sh" /usr/local/lib/omaconf/
install -m 644 -o root -g root "$PROJECT_DIR/conf/xdg-desktop-portal/data/portals.conf" \
    "$PROJECT_DIR/conf/desktop/data/mpv.desktop" /usr/local/lib/omaconf/
install -m 644 -o root -g root "$PROJECT_DIR"/scripts/lib/messages/*.msg /usr/local/lib/omaconf/messages/
install -Dm755 -o root -g root "$PROJECT_DIR/scripts/lib/update-previews.sh" /usr/local/libexec/omaconf-update-previews
cat > /etc/pacman.d/hooks/99-omaconf-theme-previews.hook << 'HOOK'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Path
Target = usr/share/omarchy/themes/*

[Action]
When = PostTransaction
Exec = /usr/local/libexec/omaconf-update-previews
HOOK
chmod 644 /etc/pacman.d/hooks/99-omaconf-theme-previews.hook

if [[ -f "$PROJECT_DIR/scripts/lib/theme-preview.sh" ]]; then
    # shellcheck source=../theme-preview.sh
    source "$PROJECT_DIR/scripts/lib/theme-preview.sh"
fi

log "theming.desktop"
for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    _mode_marker="$user_home/.local/state/omaconf/dark-default"
    if [[ ! -f "$_mode_marker" ]]; then
        _palette="$user_home/.local/state/omarchy/current/theme/colors.toml"
        if [[ ! -f "$_palette" ]] || ! grep -qE '^mode[[:space:]]*=[[:space:]]*"dark"' "$_palette"; then
            for _candidate in /usr/share/omarchy/themes/*/colors.toml; do
                if grep -qE '^mode[[:space:]]*=[[:space:]]*"dark"' "$_candidate"; then
                    _slug=$(basename "$(dirname "$_candidate")")
                    omarchy_as "$_user" theme set "$_slug"
                    break
                fi
            done
        fi
        install -d -m 700 -o "$_user" -g "$_user" "$(dirname "$_mode_marker")"
        printf 'dark\n' > "$_mode_marker"
        chown "$_user:$_user" "$_mode_marker"
    fi
done
for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    _uid=$(id -u "$_user" 2>/dev/null) || continue

    if [[ -e "/run/user/$_uid/bus" ]]; then
        user_as "$_user" gsettings set org.gnome.desktop.interface cursor-theme "capitaine-cursors" 2>/dev/null || warn "theming.cursor_skipped" "$_user"
    fi

    mkdir -p "$user_home/.icons/default"
    cat > "$user_home/.icons/default/index.theme" << 'EOF'
[Icon Theme]
Name=default
Comment=Fallback cursor theme
Inherits=capitaine-cursors
EOF
    chown -R "$_user":"$_user" "$user_home/.icons" 2>/dev/null || warn "theming.icons_chown" "$_user"

    _hyland="$user_home/.config/hypr/hyprland.lua"
    if [[ -f "$_hyland" ]] && grep -q '^-- omablot cursor env (managed)$' "$_hyland"; then
        sed -i '/^-- omablot cursor env (managed)$/,/^-- end omablot cursor env (managed)$/d' "$_hyland" || warn "theming.cursor_migration_skipped" "$_user"
        chown "$_user":"$_user" "$_hyland" 2>/dev/null || warn "theming.hypr_chown" "$_user"
    fi
    if [[ -f "$_hyland" ]] && ! grep -q 'omaconf cursor env' "$_hyland" 2>/dev/null; then
        cat >> "$_hyland" << 'LUAEOF'

-- omaconf cursor env (managed)
hl.env("XCURSOR_THEME", "capitaine-cursors")
hl.env("HYPRCURSOR_THEME", "capitaine-cursors")
-- end omaconf cursor env (managed)
LUAEOF
        chown "$_user":"$_user" "$_hyland" 2>/dev/null || warn "theming.hypr_chown" "$_user"
    fi
    if [[ -f "$_hyland" ]] && ! grep -q 'omaconf qt env' "$_hyland" 2>/dev/null; then
        cat >> "$_hyland" << 'LUAEOF'

-- omaconf qt env (managed)
hl.env("QT_QPA_PLATFORMTHEME", "xdgdesktop")
-- end omaconf qt env (managed)
LUAEOF
        chown "$_user":"$_user" "$_hyland" 2>/dev/null || warn "theming.hypr_chown" "$_user"
    fi
done

log "theming.preview_size"
if declare -F theme_preview_normalize >/dev/null; then
    theme_preview_normalize || warn "theming.preview_size_skipped"
fi

log "theming.hooks"
for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    _hook_dir="$user_home/.config/omarchy/hooks/theme-set.d"
    _i18n_dir="$user_home/.config/omarchy/hooks/i18n"
    _lib_dir="$user_home/.config/omarchy/hooks/lib"
    mkdir -p "$_hook_dir" "$_i18n_dir/messages" "$_lib_dir"
    rm -f "$_hook_dir/yazi-theme" "$user_home/.local/share/applications/yazi-terminal.desktop"
    cp "$PROJECT_DIR/scripts/lib/i18n.sh" "$PROJECT_DIR/scripts/lib/i18n-boot.sh" "$_i18n_dir/"
    cp "$PROJECT_DIR"/scripts/lib/messages/*.msg "$_i18n_dir/messages/"
    cp "$PROJECT_DIR/scripts/lib/theme-preview.sh" "$_lib_dir/"
    cp "$PROJECT_DIR/scripts/lib/desktop-workflow.sh" "$_lib_dir/"
    cp "$PROJECT_DIR/conf/xdg-desktop-portal/data/portals.conf" "$_lib_dir/"
    cp "$PROJECT_DIR/conf/desktop/data/mpv.desktop" "$_lib_dir/"
    chmod 644 "$_i18n_dir/i18n.sh" "$_i18n_dir"/messages/*.msg "$_lib_dir/theme-preview.sh"
    chown "$_user":"$_user" "$user_home/.config/omarchy" "$user_home/.config/omarchy/hooks"
    chown -R "$_user":"$_user" "$_hook_dir" "$_i18n_dir" "$_lib_dir"
    for hook_file in "$PROJECT_DIR"/hooks/theme-set.d/*; do
        [[ -f "$hook_file" ]] || continue
        hook_name=$(basename "$hook_file")
        install -m 755 -o "$_user" -g "$_user" "$hook_file" "$_hook_dir/$hook_name"
        user_as "$_user" bash "$_hook_dir/$hook_name" || warn "theming.hook_failed" "$hook_name" "$_user"
    done
done

if [[ "${OMACONF_REBUILD_PREVIEWS:-0}" == 1 ]]; then
    mapfile -t _preview_themes < <(find /usr/share/omarchy/themes -mindepth 2 -maxdepth 2 -name colors.toml -printf '%h\n' | sed 's|.*/||' | sort)
    bash -n "$PROJECT_DIR/theme-previews/rebuild-previews.sh"
    user_as "$PRIMARY_USER" env "OMARCHY_PATH=${OMARCHY_PATH:-/usr/share/omarchy}" OMACONF_APPLY_PIPELINE=1 bash -c "$(cat "$PROJECT_DIR/theme-previews/rebuild-previews.sh")" "$PROJECT_DIR/theme-previews/rebuild-previews.sh" "${_preview_themes[@]}"
fi
mapfile -t _preview_themes < <(find "$PROJECT_DIR/theme-previews" -mindepth 2 -maxdepth 2 -name preview.png -printf '%h\n' | sed 's|.*/||' | sort)
for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    user_as "$_user" bash "$PROJECT_DIR/theme-previews/apply.sh" "${_preview_themes[@]}"
done

_browser_palette="$(getent passwd "$PRIMARY_USER" | cut -d: -f6)/.local/state/omarchy/current/theme/colors.toml"
if [[ -f "$_browser_palette" && -x /usr/bin/omarchy-theme-set-browser-policy ]]; then
    _browser_color=$(awk -F '"' '/^background[[:space:]]*=/ { print tolower(substr($2, 2)); exit }' "$_browser_palette")
    [[ "$_browser_color" =~ ^[0-9a-f]{6}$ ]] || err "hooks.gtk_palette_failed" "$_browser_palette"
    bash /usr/bin/omarchy-theme-set-browser-policy "$_browser_color"
    _browser_uid=$(id -u "$PRIMARY_USER")
    if pgrep -u "$_browser_uid" -x brave-origin >/dev/null; then
        user_as "$PRIMARY_USER" brave-origin --refresh-platform-policy --no-startup-window
    fi
fi
