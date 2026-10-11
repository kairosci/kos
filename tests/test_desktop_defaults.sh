#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OMAQT_MODULE="$PROJECT_DIR/scripts/lib/modules/32-omaqt.sh"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Independent Desktop Applications"

ENV_MODULE="$PROJECT_DIR/scripts/lib/modules/00-env.sh"
THEMING_MODULE="$PROJECT_DIR/scripts/lib/modules/30-theming.sh"

assert_file_contains "env module defines the per-user command helper" "$ENV_MODULE" "user_as()"
assert_file_contains "per-user helper forwards HOME" "$ENV_MODULE" 'HOME=.home.'
assert_file_contains "per-user helper forwards the runtime dir" "$ENV_MODULE" 'XDG_RUNTIME_DIR=.runtime.'
assert_file_contains "per-user helper forwards the session bus" "$ENV_MODULE" 'DBUS_SESSION_BUS_ADDRESS=.bus.'
assert_file_contains "per-user helper forwards the active language" "$ENV_MODULE" 'OMACONF_LANG=.OMACONF_LANG.'
assert_file_contains "omarchy_as delegates to the per-user helper" "$ENV_MODULE" 'OMARCHY_PATH=.OMARCHY_PATH. omarchy'
assert_true "omarchy_as passes environment and arguments as separate command tokens" "(
    source <(sed -n '/^omarchy_as()/,\$p' '$ENV_MODULE')
    export OMARCHY_PATH='/path with spaces'
    user_as() { [[ \$# == 6 && \$1 == testuser && \$2 == env && \$3 == 'OMARCHY_PATH=/path with spaces' && \$4 == omarchy && \$5 == theme && \$6 == 'theme with spaces' ]]; }
    omarchy_as testuser theme 'theme with spaces'
)"

assert_file_contains "theming runs hooks through the per-user helper" "$THEMING_MODULE" 'user_as .._user. bash .._hook_dir/.hook_name.'
assert_file_not_contains "omaqt does not route xdg-mime through omarchy" "$OMAQT_MODULE" 'omarchy_as "$_user" xdg-mime'
assert_file_not_contains "omaqt does not route gio through omarchy" "$OMAQT_MODULE" 'omarchy_as "$_user" gio'

DEBLOAT_MODULE="$PROJECT_DIR/scripts/lib/modules/10-debloat.sh"
DEFAULTS_MODULE="$PROJECT_DIR/scripts/lib/modules/20-defaults.sh"
SHELL_PLUGINS_MODULE="$PROJECT_DIR/scripts/lib/modules/35-shell-plugins.sh"

assert_file_not_contains "defaults never sets the browser as root" "$DEFAULTS_MODULE" 'omarchy default browser'

assert_file_contains "debloat module removes IgnorePkg entries" "$DEBLOAT_MODULE" "IgnorePkg"
assert_file_not_contains "debloat module keeps no merged pin list" "$DEBLOAT_MODULE" "EXISTING_PINS"
assert_file_contains "debloat module installs persistence hooks" "$DEBLOAT_MODULE" "99-omaconf-persist"
assert_file_contains "defaults module records file-manager state" "$PROJECT_DIR/scripts/lib/desktop-workflow.sh" "defaults/file-manager"
assert_file_contains "defaults module rebinds file manager keys to Nautilus" "$DEFAULTS_MODULE" "omaconf-nautilus-fm"
assert_file_contains "defaults module provisions herdrconf menu" "$PROJECT_DIR/scripts/lib/modules/24-user-configurations.sh" "conf/\*/install.sh"
assert_file_contains "defaults module installs Baobab disk analyzer" "$DEFAULTS_MODULE" "baobab"
assert_file_contains "defaults module installs Micro symbol navigation dependencies" "$DEFAULTS_MODULE" "universal-ctags"
assert_file_contains "defaults module provisions diskconf" "$PROJECT_DIR/scripts/lib/modules/24-user-configurations.sh" "conf/\*/install.sh"
assert_file_contains "shell plugins module uses canonical omamp source" "$SHELL_PLUGINS_MODULE" "omaconf/omamp.git"
assert_file_contains "env module defines omarchy_as helper" "$PROJECT_DIR/scripts/lib/modules/00-env.sh" "omarchy_as\(\)"
assert_file_contains "omarchy_as forwards the user session bus" "$PROJECT_DIR/scripts/lib/modules/00-env.sh" "DBUS_SESSION_BUS_ADDRESS"
assert_file_contains "defaults module configures Brave through xdg-settings" "$DEFAULTS_MODULE" "xdg-settings set default-web-browser brave-origin.desktop"
assert_file_contains "defaults module installs Brave" "$DEFAULTS_MODULE" "aur_verified_install brave-origin-bin"
assert_file_contains "defaults module installs Slack and Discord" "$DEFAULTS_MODULE" "for pkg in slack-desktop discord"
assert_file_contains "defaults module installs app configurations for each user" "$PROJECT_DIR/scripts/lib/modules/24-user-configurations.sh" "conf/\*/install.sh"
assert_file_contains "setup.sh references shell plugins module" "$PROJECT_DIR/scripts/setup.sh" "35-shell-plugins.sh"
assert_file_contains "setup.sh references portals module" "$PROJECT_DIR/scripts/setup.sh" "22-portals.sh"
assert_file_contains "setup.sh references keyring module" "$PROJECT_DIR/scripts/setup.sh" "62-keyring.sh"
assert_file_contains "portals module installs the GTK backend" "$PROJECT_DIR/scripts/lib/modules/22-portals.sh" "xdg-desktop-portal-gtk"
assert_file_contains "keyring module provisions libsecret and pass" "$PROJECT_DIR/scripts/lib/modules/62-keyring.sh" "libsecret"
assert_file_contains "keyring module masks gnome-keyring" "$PROJECT_DIR/scripts/lib/modules/62-keyring.sh" "gnome-keyring-daemon"
assert_file_contains "keyring module restores GNOME service" "$PROJECT_DIR/scripts/lib/modules/62-keyring.sh" "enable --now"
assert_file_contains "keyring module selects GNOME backend" "$PROJECT_DIR/scripts/lib/modules/62-keyring.sh" "KEYRING_BACKEND=gnome-keyring"
assert_file_contains "keyring module provisions Seahorse" "$PROJECT_DIR/scripts/lib/modules/62-keyring.sh" "seahorse"
assert_file_contains "keyring switch accepts GNOME backend" "$PROJECT_DIR/scripts/keyring-switch.sh" "gnome-keyring)"
assert_file_contains "Makefile exposes the keyring selection target" "$PROJECT_DIR/Makefile" "scripts/keyring-switch.sh"

PERSIST_PRE="$PROJECT_DIR/hooks/pre-refresh-pacman.d/99-omaconf-persist"
assert_file_exists "pre-refresh persist hook exists in repo" "$PERSIST_PRE"
assert_file_executable "pre-refresh persist hook executable" "$PERSIST_PRE"
assert_file_not_contains "pre-refresh hook keeps no IgnorePkg" "$PERSIST_PRE" "IgnorePkg"

PERSIST_POST="$PROJECT_DIR/hooks/post-update.d/99-omaconf-persist"
assert_file_exists "post-update persist hook exists in repo" "$PERSIST_POST"
assert_file_executable "post-update persist hook executable" "$PERSIST_POST"
assert_false "pre-refresh excludes retired omasec pins" "grep -q '/etc/pacman.d/omasec' '$PERSIST_PRE'"
assert_false "post-update excludes retired omasec pins" "grep -q '/etc/pacman.d/omasec' '$PERSIST_POST'"
assert_file_not_contains "pre-refresh never escalates package policy changes" "$PERSIST_PRE" 'sudo'
assert_file_not_contains "post-update never removes packages" "$PERSIST_POST" 'pacman -Rns'
assert_file_contains "setup aborts on failed debloat" "$DEBLOAT_MODULE" 'err "debloat.partial_removal"'
assert_true "pre-refresh always succeeds without pins" "bash '$PERSIST_PRE'"
assert_true "pre-refresh ignores a stale pin file" "OMACONF_PIN_FILE='/nonexistent/pins' bash '$PERSIST_PRE'"
source "$PROJECT_DIR/scripts/lib/package-pins.sh"
_pin_fixture=$(mktemp)
printf 'IgnorePkg = nautilus brave-origin-bin linux-lts\n  IgnorePkg = linux-lts custom-hold # retained\n' > "$_pin_fixture"
assert_true "all user pins survive retained package migration" "[[ \$(package_pins_existing '$_pin_fixture') == 'linux-lts custom-hold ' ]]"
# shellcheck disable=SC2329
pacman-conf() { printf 'linux-lts\n'; }
assert_true "retained packages can update with unrelated holds" 'package_pins_retained_updateable'
# shellcheck disable=SC2329
pacman-conf() { printf 'nautilus\n'; }
assert_false "retained package holds fail verification" 'package_pins_retained_updateable'
# shellcheck disable=SC2329
pacman-conf() { printf 'brave-*\n'; }
assert_false "wildcard retained package holds fail verification" 'package_pins_retained_updateable'
# shellcheck disable=SC2329
pacman-conf() { printf ''; }
assert_true "empty holds keep retained packages updateable" 'package_pins_retained_updateable'
# shellcheck disable=SC2329
pacman-conf() { return 42; }
assert_false "retained package verification propagates query failure" 'package_pins_retained_updateable'
unset -f pacman-conf
rm -f "$_pin_fixture"
assert_file_contains "post-update hook delegates shared desktop defaults" "$PERSIST_POST" "desktop_workflow_defaults"
assert_file_contains "post-update hook reapplies Papers default" "$PROJECT_DIR/scripts/lib/desktop-workflow.sh" "org.gnome.Papers.desktop application/pdf"
assert_file_contains "post-update hook reapplies image defaults" "$PROJECT_DIR/scripts/lib/desktop-workflow.sh" "org.gnome.Loupe.desktop image/png"
assert_file_contains "post-update hook reapplies media defaults" "$PROJECT_DIR/scripts/lib/desktop-workflow.sh" "io.github.celluloid_player.Celluloid.desktop video/mp4"
assert_file_contains "post-update hook removes crash-watch" "$PERSIST_POST" "omarchy-crash-watch.service"

assert_file_exists "omaqt integration module exists" "$OMAQT_MODULE"
assert_file_executable "omaqt integration module executable" "$OMAQT_MODULE"
assert_file_contains "omaqt integration module uses strict mode" "$OMAQT_MODULE" "set -euo pipefail"
assert_file_contains "setup.sh references omaqt module" "$PROJECT_DIR/scripts/setup.sh" "32-omaqt.sh"
assert_file_not_contains "omaqt module hardcodes no upstream repo URL" "$OMAQT_MODULE" "github.com/omasec-org"
assert_file_contains "omaqt module takes its URL from the environment" "$OMAQT_MODULE" '^OMAQT_URL='
assert_file_contains "omaqt module defaults the URL to empty" "$OMAQT_MODULE" 'OMAQT_URL:-'
assert_file_contains "omaqt module logs a clean skip when unconfigured" "$OMAQT_MODULE" "omaqt.unconfigured"
assert_file_contains "omaqt module returns early because it is sourced" "$OMAQT_MODULE" "return 0"
assert_file_not_contains "omaqt module never exits the sourcing setup" "$OMAQT_MODULE" "exit 0"
assert_file_contains "omaqt module delegates to omaqt installer" "$OMAQT_MODULE" "install.sh"
assert_file_contains "omaqt module tracks omaqt checkout" "$OMAQT_MODULE" "OMAQT_DIR"
assert_file_contains "omaqt module applies omaqt under usr/share/omarchy" "$OMAQT_MODULE" "/usr/share/omarchy/omaqt"
assert_file_contains "omaqt module degrades gracefully on clone failure" "$OMAQT_MODULE" "|| warn"
assert_file_not_contains "omaqt module no longer duplicates the yazi default" "$OMAQT_MODULE" "inode/directory"


OMAQT_DIR="/usr/share/omarchy/omaqt"
if [[ -x "$OMAQT_DIR/install.sh" ]]; then
    for app in imv mpv qogir-icon-theme; do
        assert_file_contains "omaqt installer installs $app" "$OMAQT_DIR/install.sh" "$app"
    done
    for app in nautilus totem evince eog yaru-icon-theme dolphin okular gwenview \
        xdg-desktop-portal-kde plasma-integration breeze breeze-gtk; do
        assert_file_contains "omaqt installer pins removed $app" "$OMAQT_DIR/install.sh" "$app"
    done
    assert_file_contains "omaqt installer removes GNOME apps" "$OMAQT_DIR/install.sh" "Removing GNOME default applications"
    assert_file_contains "omaqt installer removes KDE apps" "$OMAQT_DIR/install.sh" "Removing the KDE desktop stack"
    assert_file_contains "omaqt installer removes packages recursively" "$OMAQT_DIR/install.sh" "Rns --noconfirm"
    assert_false "omaqt installer does not install kde portal" "sed -n '/^APP_PKGS=/,/^)/p' $OMAQT_DIR/install.sh | grep -q 'xdg-desktop-portal-kde'"
    assert_file_contains "omaqt installer removes system portal override" "$OMAQT_DIR/install.sh" "portals.conf"
    assert_file_contains "omaqt installer sets imv mime default" "$OMAQT_DIR/install.sh" "imv.desktop image"
    assert_file_contains "omaqt installer sets mpv mime default" "$OMAQT_DIR/install.sh" "mpv.desktop video"
    assert_true "omaqt installer sets a yazi mime default" \
        "grep -qE 'yazi(-terminal)?\\.desktop inode/directory' '$OMAQT_DIR/install.sh'"
    assert_file_contains "omaqt installer cleans stale KDE hooks" "$OMAQT_DIR/install.sh" "kde-folder-color"
fi

if command -v pacman &>/dev/null && [[ -f /etc/arch-release ]]; then
    for app in nautilus zed loupe celluloid qogir-icon-theme; do
        assert_true "$app installed" "pacman -Q $app &>/dev/null"
    done
    for app in thunar totem evince eog yaru-icon-theme dolphin okular gwenview \
        xdg-desktop-portal-kde plasma-integration breeze breeze-gtk haruna; do
        assert_false "$app not installed" "pacman -Q $app &>/dev/null"
    done
fi

if command -v pacman &>/dev/null && [[ -f /etc/arch-release ]] && [[ -f /etc/mime.types ]]; then
    assert_true "pdf default is Papers" "xdg-mime query default application/pdf 2>/dev/null | grep -q 'org.gnome.Papers'"
    assert_true "image default is Loupe" "xdg-mime query default image/jpeg 2>/dev/null | grep -q 'org.gnome.Loupe'"
    assert_true "video default is Celluloid" "xdg-mime query default video/mp4 2>/dev/null | grep -q 'celluloid_player.Celluloid'"
    assert_true "directory default is Nautilus" "xdg-mime query default inode/directory 2>/dev/null | grep -q 'org.gnome.Nautilus.desktop'"
fi

if [[ -f /etc/xdg/xdg-desktop-portal/portals.conf ]]; then
    assert_false "no system portal override" "grep -q '^default=kde' /etc/xdg/xdg-desktop-portal/portals.conf"
fi

test_summary
