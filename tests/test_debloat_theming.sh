#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEBLOAT_MODULE="$PROJECT_DIR/scripts/lib/modules/10-debloat.sh"
DEFAULTS_MODULE="$PROJECT_DIR/scripts/lib/modules/20-defaults.sh"
THEMING_MODULE="$PROJECT_DIR/scripts/lib/modules/30-theming.sh"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Debloat, Application Parity & Theming"

assert_file_exists "debloat module exists" "$DEBLOAT_MODULE"
assert_file_contains "debloat module defines package removal" "$DEBLOAT_MODULE" "pacman -Rns"
assert_file_contains "debloat module removes IgnorePkg entries" "$DEBLOAT_MODULE" "IgnorePkg"
assert_file_not_contains "debloat module keeps no merged pin list" "$DEBLOAT_MODULE" "MERGED_PINS"
assert_file_not_contains "debloat module preserves no existing pins" "$DEBLOAT_MODULE" "EXISTING_PINS"
assert_file_contains "debloat module installs persistence hooks" "$DEBLOAT_MODULE" "99-omaconf-persist"
assert_file_contains "debloat removes Neovim" "$DEBLOAT_MODULE" "neovim"
assert_file_contains "debloat removes the Omarchy Neovim package" "$DEBLOAT_MODULE" "omarchy-nvim"
assert_file_contains "debloat module removes the sushi previewer orphan" "$DEBLOAT_MODULE" "sushi"
assert_file_contains "debloat module removes the sushi sourceview dependency" "$DEBLOAT_MODULE" "gtksourceview4"
assert_file_contains "debloat module removes the sushi gtk plugin dependency" "$DEBLOAT_MODULE" "gst-plugin-gtk"
assert_file_exists "desktop-applications skill exists" "$PROJECT_DIR/.skills/desktop-applications/SKILL.md"
assert_file_contains "desktop-applications skill registered in the agent contract" "$PROJECT_DIR/AGENTS.md" "desktop-applications"

assert_file_exists "defaults module exists" "$DEFAULTS_MODULE"
assert_true "Brave Origin is not part of the DEBLOAT package list" "! sed -n '/^DEBLOAT=(/,/^)/p' '$DEBLOAT_MODULE' | grep -q brave-origin-bin"
assert_true "standard Brave is removed and pinned" "sed -n '/^DEBLOAT=(/,/^)/p' '$DEBLOAT_MODULE' | grep -qx '    brave-bin'"
assert_file_contains "defaults module configures 7zip archive support" "$DEFAULTS_MODULE" "7zip"
assert_file_contains "defaults module installs Kitty" "$DEFAULTS_MODULE" "pacman -S --noconfirm --needed kitty"
assert_file_contains "defaults module configures trash-cli safe delete" "$DEFAULTS_MODULE" "trash-cli"
assert_file_contains "defaults module configures Celluloid player" "$DEFAULTS_MODULE" "celluloid"

assert_file_exists "theming module exists" "$THEMING_MODULE"
assert_file_contains "theming module installs hooks" "$THEMING_MODULE" "hooks/theme-set.d"
assert_file_contains "theming module propagates color-scheme from the active theme" "$PROJECT_DIR/hooks/theme-set.d/gtk-theme" "gsettings set org.gnome.desktop.interface color-scheme"
assert_file_not_contains "theming module does not write GTK settings" "$THEMING_MODULE" "gtk-settings"
assert_file_contains "theming module routes Qt through the xdgdesktop platform theme" "$THEMING_MODULE" 'QT_QPA_PLATFORMTHEME", "xdgdesktop"'
assert_file_exists "theme preview apply helper exists" "$PROJECT_DIR/theme-previews/apply.sh"
assert_file_contains "theme preview apply creates missing user overlays" "$PROJECT_DIR/theme-previews/apply.sh" 'install -d -m 700'
assert_file_contains "theme preview apply clears selector cache" "$PROJECT_DIR/theme-previews/apply.sh" 'theme-selector'

REBUILD_PREVIEWS="$PROJECT_DIR/theme-previews/rebuild-previews.sh"
assert_file_exists "theme preview rebuild helper exists" "$REBUILD_PREVIEWS"
assert_file_not_contains "rebuild script no longer hardcodes a default theme list" "$REBUILD_PREVIEWS" 'themes=\(last-horizon lupine\)'
assert_file_not_contains "rebuild script no longer special-cases lupine" "$REBUILD_PREVIEWS" "theme.*==.*'lupine'"

PREVIEW_LIB="$PROJECT_DIR/scripts/lib/theme-preview.sh"
assert_file_exists "theme preview normalization library exists" "$PREVIEW_LIB"
assert_file_contains "theme preview library declares the canvas" "$PREVIEW_LIB" "THEME_PREVIEW_CANVAS"
assert_file_contains "theme preview canvas matches the stock theme grid" "$PREVIEW_LIB" "1800x1012"
assert_file_contains "theme preview library keeps the stock backup" "$PREVIEW_LIB" "theme-preview-stock"
assert_file_contains "theme preview library backs the original up" "$PREVIEW_LIB" 'cp -a "\$preview" "\$original"'
assert_file_contains "theme preview library resizes with magick" "$PREVIEW_LIB" "magick"
assert_file_contains "theme preview library installs the result" "$PREVIEW_LIB" "install -m 644"
assert_file_contains "theme preview library requires an alpha channel" "$PREVIEW_LIB" '\[\[ "\$type" == \*Alpha \]\]'
assert_file_contains "theme preview library writes an rgba png" "$PREVIEW_LIB" "PNG32:"
assert_true "theme preview library never forces pixel density units" "! grep -q 'PixelsPerInch' '$PREVIEW_LIB'"
assert_file_contains "theme preview library keeps the overlay store" "$PREVIEW_LIB" "theme-preview-overlay"
assert_file_contains "theme preview library restores stored overlays" "$PREVIEW_LIB" "theme_preview_restore_overlays"
assert_file_contains "theming module sources the preview library" "$THEMING_MODULE" "lib/theme-preview.sh"
assert_file_contains "theming module normalizes preview size" "$THEMING_MODULE" "theme_preview_normalize"
assert_file_contains "theming module deploys the preview library to hooks lib" "$THEMING_MODULE" 'hooks/lib'
assert_file_contains "post-update hook resolves the deployed preview library" "$PROJECT_DIR/hooks/post-update.d/99-omaconf-persist" "lib/theme-preview.sh"
assert_file_contains "post-update hook reapplies preview normalization" "$PROJECT_DIR/hooks/post-update.d/99-omaconf-persist" "theme_preview_normalize"
assert_file_contains "setup deploys privileged preview transaction hook" "$THEMING_MODULE" '99-omaconf-theme-previews.hook'
assert_file_contains "preview hook targets packaged themes" "$THEMING_MODULE" 'Target = usr/share/omarchy/themes/'
assert_file_contains "preview transaction uses only privileged libraries" "$PROJECT_DIR/scripts/lib/update-previews.sh" 'source /usr/local/lib/omaconf/theme-preview.sh'
assert_false "user hook no longer warns about privileged previews" "grep -q 'hooks.preview_size_reapply_root_skipped' '$PROJECT_DIR/hooks/post-update.d/99-omaconf-persist'"

REBUILD_GEOMETRY="$PROJECT_DIR/theme-previews/rebuild-previews.sh"
assert_file_contains "rebuild script captures Zed" "$REBUILD_GEOMETRY" 'capture_app zed'
assert_file_contains "rebuild script captures Nautilus" "$REBUILD_GEOMETRY" 'capture_app org.gnome.Nautilus'
assert_file_contains "rebuild script fills both halves of the work area" "$REBUILD_GEOMETRY" 'theme_preview_window_geometry'
assert_file_contains "rebuild script writes the composite as rgba" "$REBUILD_GEOMETRY" 'PNG32:\$output_dir/preview.png'

PREVIEW_APPLY="$PROJECT_DIR/theme-previews/apply.sh"
assert_file_contains "apply helper supports a system scope" "$PREVIEW_APPLY" "SYSTEM_SCOPE"
assert_file_contains "apply helper installs system previews as root" "$PREVIEW_APPLY" 'install -m 644 -o root -g root'
assert_file_contains "apply helper records the overlay for the post-update hook" "$PREVIEW_APPLY" "theme_preview_store_overlay"
assert_file_contains "apply helper refuses an implicit system scope" "$PREVIEW_APPLY" "System scope requires explicit themes"

if command -v magick &>/dev/null; then
    PREVIEW_SANDBOX="$(mktemp -d)"
    mkdir -p "$PREVIEW_SANDBOX/themes/last-horizon" "$PREVIEW_SANDBOX/themes/nord" "$PREVIEW_SANDBOX/themes/lupine" \
        "$PREVIEW_SANDBOX/cache" "$PREVIEW_SANDBOX/store"
    magick -size 2880x1800 xc:red "$PREVIEW_SANDBOX/themes/last-horizon/preview.png"
    magick -size 1800x1012 xc:blue -alpha off "$PREVIEW_SANDBOX/themes/nord/preview.png"
    magick -size 1800x1012 xc:green "$PREVIEW_SANDBOX/store/lupine.png"
    magick -size 2880x1800 xc:yellow "$PREVIEW_SANDBOX/themes/lupine/preview.png"
    (
        set -euo pipefail
        # shellcheck disable=SC2329
        warn() { printf '%s\n' "$1" >&2; }
        # shellcheck disable=SC2329
        log() { :; }
        # shellcheck source=../scripts/lib/theme-preview.sh
        source "$PREVIEW_LIB"
        THEME_PREVIEW_THEMES_ROOT="$PREVIEW_SANDBOX/themes"
        THEME_PREVIEW_BACKUP_DIR="$PREVIEW_SANDBOX/cache"
        THEME_PREVIEW_OVERLAY_STORE="$PREVIEW_SANDBOX/store"
        theme_preview_normalize
    ) 2>/dev/null
    assert_true "theme preview library normalizes an oversized stock preview" \
        "[[ \"\$(identify -format '%wx%h' '$PREVIEW_SANDBOX/themes/last-horizon/preview.png')\" == 1800x1012 ]]"
    assert_true "theme preview library leaves a preview already on the canvas alone" \
        "[[ \"\$(identify -format '%wx%h' '$PREVIEW_SANDBOX/themes/nord/preview.png')\" == 1800x1012 ]]"
    assert_true "theme preview library adds the missing alpha channel" \
        "[[ \"\$(identify -format '%[type]' '$PREVIEW_SANDBOX/themes/nord/preview.png')\" == *Alpha ]]"
    assert_true "theme preview library keeps the stock density at 72" \
        "[[ \"\$(identify -format '%x' '$PREVIEW_SANDBOX/themes/nord/preview.png')\" == 72 ]]"
    assert_true "theme preview library normalizes depth to 8" \
        "[[ \"\$(identify -format '%z' '$PREVIEW_SANDBOX/themes/nord/preview.png')\" == 8 ]]"
    assert_true "theme preview library keeps the stock original as a backup" \
        "[[ -f '$PREVIEW_SANDBOX/cache/last-horizon-2880x1800.png' ]]"
    assert_true "theme preview library restores a stored overlay" \
        "cmp -s '$PREVIEW_SANDBOX/store/lupine.png' '$PREVIEW_SANDBOX/themes/lupine/preview.png'"
    assert_true "theme preview library is idempotent" \
        "before=\$(md5sum '$PREVIEW_SANDBOX'/themes/*/preview.png); source '$PREVIEW_LIB'; THEME_PREVIEW_THEMES_ROOT='$PREVIEW_SANDBOX/themes' THEME_PREVIEW_BACKUP_DIR='$PREVIEW_SANDBOX/cache' THEME_PREVIEW_OVERLAY_STORE='$PREVIEW_SANDBOX/store' theme_preview_normalize; after=\$(md5sum '$PREVIEW_SANDBOX'/themes/*/preview.png); [[ \"\$before\" == \"\$after\" ]]"
    rm -rf "$PREVIEW_SANDBOX"
fi

if command -v pacman &>/dev/null && [[ -f /etc/arch-release ]]; then
    assert_true "herdr installed" "pacman -Q herdr &>/dev/null"
    assert_true "gum installed" "pacman -Q gum &>/dev/null"
    assert_true "Nautilus installed" "pacman -Q nautilus &>/dev/null"
    for app in zed papers loupe celluloid baobab resources onlyoffice-bin; do
        assert_true "$app installed" "pacman -Q '$app' &>/dev/null"
    done
    assert_true "7zip installed" "pacman -Q 7zip &>/dev/null"
    assert_true "mpv installed" "pacman -Q mpv &>/dev/null"
    assert_true "capitaine-cursors installed" "pacman -Q capitaine-cursors &>/dev/null"
    assert_true "qogir-icon-theme installed" "pacman -Q qogir-icon-theme &>/dev/null"

    assert_true "kitty terminal installed" "pacman -Q kitty &>/dev/null"
    assert_false "foot terminal removed" "pacman -Q foot &>/dev/null"
    for debloated in chromium zathura zathura-pdf-mupdf thunar thunar-archive-plugin tumbler yaru-icon-theme system-config-printer totem evince eog dolphin okular gwenview xdg-desktop-portal-kde breeze breeze-gtk haruna kdenlive obs-studio libreoffice-fresh obsidian gnome-disk-utility gnome-themes-extra sushi gtksourceview4 gst-plugin-gtk foot neovim omarchy-nvim micro imv mupdf btop gdu mpv-mpris libreoffice-still; do
        assert_false "debloat verified: $debloated removed" "pacman -Q '$debloated' &>/dev/null"
    done
    assert_false "docker daemon absent" "command -v dockerd &>/dev/null"
    assert_true "podman installed" "pacman -Q podman &>/dev/null"
fi

if command -v pacman &>/dev/null && [[ -f /etc/arch-release ]]; then
    assert_false "stale ignore-pkgs.list is gone" "[[ -f /etc/pacman.d/omaconf/ignore-pkgs.list ]]"
    assert_false "pacman.conf carries no IgnorePkg" "grep -q '^[[:space:]]*IgnorePkg[[:space:]]*=' /etc/pacman.conf"
fi

HOOK_FILE="$PROJECT_DIR/hooks/theme-set.d/folder-color"
assert_file_exists "folder-color hook exists in repo" "$HOOK_FILE"
assert_file_executable "folder-color hook executable" "$HOOK_FILE"


PERSIST_PRE="$PROJECT_DIR/hooks/pre-refresh-pacman.d/99-omaconf-persist"
assert_file_exists "pre-refresh persist hook exists in repo" "$PERSIST_PRE"
assert_file_executable "pre-refresh persist hook executable" "$PERSIST_PRE"
assert_file_not_contains "pre-refresh hook keeps no IgnorePkg" "$PERSIST_PRE" "IgnorePkg"

PERSIST_POST="$PROJECT_DIR/hooks/post-update.d/99-omaconf-persist"
assert_file_exists "post-update persist hook exists in repo" "$PERSIST_POST"
assert_file_executable "post-update persist hook executable" "$PERSIST_POST"
assert_file_contains "post-update hook delegates shared desktop defaults" "$PERSIST_POST" "desktop_workflow_defaults"
assert_file_contains "post-update hook reapplies GTK routing" "$PROJECT_DIR/conf/xdg-desktop-portal/data/portals.conf" "FileChooser=gtk"
assert_file_contains "post-update hook reapplies color-scheme" "$PROJECT_DIR/hooks/theme-set.d/gtk-theme" 'gsettings set org.gnome.desktop.interface color-scheme'
assert_file_contains "post-update hook stops only the gnome portal backend" "$PROJECT_DIR/scripts/lib/desktop-workflow.sh" "stop.*xdg-desktop-portal-"
assert_file_contains "post-update hook reloads portal after routing reapply" "$PROJECT_DIR/scripts/lib/desktop-workflow.sh" "systemctl --user restart xdg-desktop-portal-gtk.service xdg-desktop-portal.service"

assert_file_exists "plugin index exists" "$PROJECT_DIR/plugins/index.json"
assert_file_contains "plugin index references omamp" "$PROJECT_DIR/plugins/index.json" "omamp"

assert_file_exists "zedconf install script exists" "$PROJECT_DIR/conf/zed/install.sh"
assert_file_contains "defaults module enforces gio file manager default" "$PROJECT_DIR/scripts/lib/desktop-workflow.sh" "gio mime inode/directory"
assert_file_contains "defaults module delegates shared desktop defaults" "$DEFAULTS_MODULE" "desktop_workflow_defaults"
assert_file_contains "defaults module records file-manager state" "$PROJECT_DIR/scripts/lib/desktop-workflow.sh" "defaults/file-manager"
assert_file_contains "defaults module rebinding hypr file manager keys" "$DEFAULTS_MODULE" "omaconf-nautilus-fm"
PORTALS_MODULE="$PROJECT_DIR/scripts/lib/modules/22-portals.sh"
assert_file_contains "portals module installs the GTK backend" "$PORTALS_MODULE" "xdg-desktop-portal-gtk"
assert_file_contains "portals module routes FileChooser to GTK" "$PROJECT_DIR/conf/xdg-desktop-portal/data/portals.conf" "FileChooser=gtk"
assert_file_contains "portals module keeps the gnome portal masked" "$PROJECT_DIR/scripts/lib/desktop-workflow.sh" "mask.*xdg-desktop-portal-"
assert_file_contains "portals module stops only the stale gnome backend" "$PROJECT_DIR/scripts/lib/desktop-workflow.sh" "stop.*xdg-desktop-portal-"
assert_file_contains "portals module reloads portal after routing" "$PROJECT_DIR/scripts/lib/desktop-workflow.sh" "systemctl --user restart xdg-desktop-portal-gtk.service xdg-desktop-portal.service"

test_summary
