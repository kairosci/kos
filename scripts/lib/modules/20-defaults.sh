#!/usr/bin/env bash

set -euo pipefail

log "defaults.browser_install"
if ! pacman -Q brave-origin-bin &>/dev/null; then
    aur_verified_install brave-origin-bin || err "defaults.browser_failed"
fi
for _policy_dir in /etc/brave /etc/brave/policies /etc/brave/policies/managed; do
    [[ ! -L "$_policy_dir" ]] || err "defaults.app_failed" "$_policy_dir"
    install -d -m 755 -o root -g root "$_policy_dir"
done

log "defaults.browser"
for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    user_as "$_user" xdg-settings set default-web-browser brave-origin.desktop 2>/dev/null || warn "defaults.browser_skipped_user" "$_user"
done

log "defaults.graphical_apps"
pacman -S --noconfirm --needed zed papers loupe celluloid baobab resources materia-gtk-theme || err "defaults.app_failed" "graphical desktop"

for pkg in fzf universal-ctags shellcheck shfmt ruff yamllint; do
    if ! pacman -Q "$pkg" &>/dev/null; then
        pacman -S --noconfirm --needed "$pkg" || err "defaults.app_failed" "$pkg"
    fi
done

if ! pacman -Q onlyoffice-bin &>/dev/null; then
    aur_verified_install onlyoffice-bin || err "defaults.app_failed" "OnlyOffice"
fi

log "defaults.collaboration_apps"
for pkg in slack-desktop discord; do
    if ! pacman -Q "$pkg" &>/dev/null; then
        aur_verified_install "$pkg" || err "defaults.app_failed" "$pkg"
    fi
done

log "defaults.editor"
for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    mkdir -p "$user_home/.local/state/omarchy/defaults"
    printf 'zed\n' > "$user_home/.local/state/omarchy/defaults/editor"
    chown -R "$_user":"$_user" "$user_home/.local/state" 2>/dev/null || warn "defaults.editor_state_failed" "$_user"
done

log "defaults.7zip_install"
if ! pacman -Q 7zip &>/dev/null; then
    pacman -S --noconfirm --needed 7zip
fi

log "defaults.kitty_install"
if ! pacman -Q kitty &>/dev/null; then
    pacman -S --noconfirm --needed kitty
fi
for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    omarchy_as "$_user" default terminal kitty 2>/dev/null || warn "defaults.terminal_skipped" "$_user"
done

log "defaults.trash_install"
if ! pacman -Q trash-cli &>/dev/null; then
    pacman -S --noconfirm --needed trash-cli
fi

log "defaults.filemanager"
for pkg in nautilus gvfs gvfs-mtp file-roller; do
    pacman -S --noconfirm --needed "$pkg" || err "defaults.app_failed" "$pkg"
done
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
            -e '/^-- omaconf-yazi-fm:/,/^o\.bind("SUPER + ALT + SHIFT + F"/d' \
            "$_bindings" || warn "defaults.bindings_migration_skipped" "$_user"
        chown "$_user":"$_user" "$_bindings" 2>/dev/null || warn "defaults.bindings_chown" "$_user"
    fi
    if [[ -f "$_bindings" ]]; then
        sed -i -e 's/omaconf-thunar-fm/omaconf-nautilus-fm/g' \
            -e 's/"thunar/"nautilus/g' \
            -e 's/thunar|Thunar/org.gnome.Nautilus/g' "$_bindings"
        chown "$_user:$_user" "$_bindings"
    fi
    if [[ -f "$_bindings" ]] && ! grep -q 'omaconf-nautilus-fm' "$_bindings" 2>/dev/null; then
        cat >> "$_bindings" << 'LUAEOF'

-- omaconf-nautilus-fm
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
    if [[ -f "$_bindings" ]] && ! grep -q 'omaconf-graphical-apps' "$_bindings"; then
        cat >> "$_bindings" << 'LUAEOF'

-- omaconf-graphical-apps
hl.unbind("SUPER + SHIFT + N")
o.bind("SUPER + SHIFT + N", "Editor", "zed")
hl.unbind("SUPER + CTRL + T")
o.bind("SUPER + CTRL + T", "Activity", "resources")
LUAEOF
        chown "$_user:$_user" "$_bindings"
    fi
    if [[ -f "$_bindings" ]] && ! grep -qF 'o.window("^(dev.zed.Zed|' "$_bindings"; then
        cat >> "$_bindings" << 'LUAEOF'
o.window("^(dev.zed.Zed|org.gnome.Nautilus|org.gnome.Papers|org.gnome.Loupe|io.github.celluloid_player.Celluloid|net.nokyan.Resources|org.gnome.baobab|xdg-desktop-portal-gtk)$", { tag = "-default-opacity", opacity = "1 1" })
LUAEOF
        chown "$_user:$_user" "$_bindings"
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
for pkg in podman podman-compose podman-docker slirp4netns; do
    if ! pacman -Q "$pkg" &>/dev/null; then
        pacman -S --noconfirm --needed "$pkg" || warn "defaults.podman_failed" "$pkg"
    fi
done
systemctl enable podman.socket 2>/dev/null || warn "defaults.podman_socket_skipped"

log "defaults.cursors_install"
if ! pacman -Q capitaine-cursors &>/dev/null; then
    pacman -S --noconfirm --needed capitaine-cursors || warn "defaults.cursors_failed"
fi

log "defaults.icons_install"
if ! pacman -Q qogir-icon-theme &>/dev/null; then
    aur_verified_install qogir-icon-theme || err "defaults.icons_failed"
fi

log "desktop.sweep"
if [[ -f "$PROJECT_DIR/scripts/lib/desktop-cleanup.sh" ]]; then
    # shellcheck source=../desktop-cleanup.sh
    source "$PROJECT_DIR/scripts/lib/desktop-cleanup.sh"
    desktop_cleanup_sweep || warn "desktop.refresh_skipped"
fi
