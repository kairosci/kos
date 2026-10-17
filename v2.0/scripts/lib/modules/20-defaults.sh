#!/usr/bin/env bash

set -euo pipefail

log "defaults.packages"
"$PROJECT_DIR/script/os-lua" install-default-packages "$PRIMARY_USER" || err "defaults.app_failed" "default packages"
for _policy_dir in /etc/brave /etc/brave/policies /etc/brave/policies/managed; do
    [[ ! -L "$_policy_dir" ]] || err "defaults.app_failed" "$_policy_dir"
    install -d -m 755 -o root -g root "$_policy_dir"
done

log "defaults.browser"
for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    user_as "$_user" env -u BROWSER xdg-settings set default-web-browser brave-origin.desktop || warn "defaults.browser_skipped_user" "$_user"
done

log "defaults.graphical_apps"

BRAND_ICON="$PROJECT_ROOT/modules/iso/assets/kmono-cyan.png"
[[ -s "$BRAND_ICON" && ! -L "$BRAND_ICON" ]] || err "branding.install_failed" "$BRAND_ICON"
install -Dm644 -- "$BRAND_ICON" /usr/share/pixmaps/os.png || err "branding.install_failed" /usr/share/pixmaps/os.png

log "gui.install_done" "LazyVim"

log "defaults.editor"
for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    mkdir -p "$user_home/.local/state/omarchy/defaults"
    printf 'zed\n' > "$user_home/.local/state/omarchy/defaults/editor"
    chown -R "$_user":"$_user" "$user_home/.local/state" 2>/dev/null || warn "defaults.editor_state_failed" "$_user"
done

log "defaults.7zip_install"
log "defaults.kitty_install"
for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    omarchy_as "$_user" default terminal kitty 2>/dev/null || warn "defaults.terminal_skipped" "$_user"
done

log "defaults.trash_install"

log "defaults.system_settings"
source "$PROJECT_DIR/scripts/lib/hyprmod.sh"
source "$PROJECT_DIR/scripts/lib/wallpaper.sh"

log "defaults.filemanager"
source "$PROJECT_DIR/scripts/lib/desktop-workflow.sh"
for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    desktop_workflow_defaults "$_user" "$user_home"
    if [[ -d "$user_home/.local/share/applications" ]]; then
        user_as "$_user" update-desktop-database "$user_home/.local/share/applications"
    fi
done

log "defaults.rebind"
for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    _bindings="$user_home/.config/hypr/bindings.lua"
    if [[ -f "$_bindings" ]] && grep -qE '^-- om(ablot|aconf)-yazi-fm:' "$_bindings"; then
        sed -i \
            -e '/^-- omablot-yazi-fm:/,/^o\.bind("SUPER + ALT + SHIFT + F"/d' \
            -e '/^-- os-yazi-fm:/,/^o\.bind("SUPER + ALT + SHIFT + F"/d' \
            "$_bindings" || warn "defaults.bindings_migration_skipped" "$_user"
        chown "$_user":"$_user" "$_bindings" 2>/dev/null || warn "defaults.bindings_chown" "$_user"
    fi
    if [[ -f "$_bindings" ]]; then
        sed -i -e 's/os-thunar-fm/os-nautilus-fm/g' \
            -e 's/"thunar/"nautilus/g' \
            -e 's/thunar|Thunar/org.gnome.Nautilus/g' "$_bindings"
        chown "$_user:$_user" "$_bindings"
    fi
    if [[ -f "$_bindings" ]] && ! grep -q 'os-nautilus-fm' "$_bindings" 2>/dev/null; then
        cat >> "$_bindings" << 'LUAEOF'

-- os-nautilus-fm
hl.unbind("SUPER + SHIFT + F")
o.bind("SUPER + SHIFT + F", "File manager", "nautilus")
hl.unbind("SUPER + ALT + SHIFT + F")
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", "nautilus \"$(omarchy-cmd-terminal-cwd)\"")
LUAEOF
        chown "$_user":"$_user" "$_bindings" 2>/dev/null || warn "defaults.bindings_chown" "$_user"
    fi
    if [[ -f "$_bindings" ]]; then
        sed -i -e 's/"Editor", "geany"/"Editor", "zed"/g' -e '/^o\.window("^(geany|Geany|/d' "$_bindings"
        chown "$_user:$_user" "$_bindings"
    fi
    if [[ -f "$_bindings" ]] && ! grep -q 'os-graphical-apps' "$_bindings"; then
        cat >> "$_bindings" << 'LUAEOF'

-- os-graphical-apps
hl.unbind("SUPER + SHIFT + N")
o.bind("SUPER + SHIFT + N", "Editor", "zed")
hl.unbind("SUPER + CTRL + T")
o.bind("SUPER + CTRL + T", "Activity", "resources")
LUAEOF
        chown "$_user:$_user" "$_bindings"
    fi
    if [[ -f "$_bindings" ]] && grep -qF 'o.window("^(dev.zed.Zed|' "$_bindings" && ! grep -q 'io.github.bluemancz.hyprmod' "$_bindings"; then
        sed -i -e 's/org.gnome.Loupe|io.github.celluloid_player.Celluloid/org.gnome.Loupe|io.github.bluemancz.hyprmod|io.github.celluloid_player.Celluloid/' "$_bindings"
        chown "$_user:$_user" "$_bindings"
    fi
    if [[ -f "$_bindings" ]] && ! grep -qF 'o.window("^(dev.zed.Zed|' "$_bindings"; then
        cat >> "$_bindings" << 'LUAEOF'
o.window("^(dev.zed.Zed|org.gnome.Nautilus|org.gnome.Papers|org.gnome.Loupe|io.github.bluemancz.hyprmod|io.github.celluloid_player.Celluloid|net.nokyan.Resources|org.gnome.Resources|org.gnome.baobab|xdg-desktop-portal-gtk)$", { tag = "-default-opacity", opacity = "1 1" })
LUAEOF
        chown "$_user:$_user" "$_bindings"
    fi
    if [[ -f "$_bindings" ]] && ! grep -q 'os-system-settings' "$_bindings"; then
        cat >> "$_bindings" << 'LUAEOF'

-- os-system-settings
hl.unbind("SUPER + comma")
o.bind("SUPER + comma", "Settings", "hyprmod")
LUAEOF
        chown "$_user":"$_user" "$_bindings" 2>/dev/null || warn "defaults.bindings_chown" "$_user"
    fi
    if [[ -f "$_bindings" ]] && grep -q 'brave --incognito' "$_bindings"; then
        sed -i 's/brave --incognito/brave-origin --incognito/g' "$_bindings"
        chown "$_user":"$_user" "$_bindings"
    fi
    if [[ -f "$_bindings" ]] && ! grep -q 'brave-origin --incognito' "$_bindings" 2>/dev/null; then
        cat >> "$_bindings" << 'LUAEOF'

hl.unbind("SUPER + SHIFT + ALT + B")
o.bind("SUPER + SHIFT + ALT + B", "Private browser", { launch = "brave-origin --incognito" })
LUAEOF
        chown "$_user":"$_user" "$_bindings" 2>/dev/null || warn "defaults.bindings_chown" "$_user"
    fi
done

log "defaults.podman"
systemctl enable podman.socket 2>/dev/null || warn "defaults.podman_socket_skipped"

log "defaults.cursors_install"

log "defaults.icons_install"

log "desktop.sweep"
if [[ -f "$PROJECT_DIR/scripts/lib/desktop-cleanup.sh" ]]; then
    # shellcheck source=../desktop-cleanup.sh
    source "$PROJECT_DIR/scripts/lib/desktop-cleanup.sh"
    desktop_cleanup_sweep || warn "desktop.refresh_skipped"
fi
