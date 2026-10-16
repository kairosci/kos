#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
LIB_DIR="$PROJECT_DIR/scripts/lib"
[[ -f "$LIB_DIR/i18n.sh" ]] || LIB_DIR="$(dirname "$SCRIPT_DIR")"
source "$LIB_DIR/i18n.sh"
source "$LIB_DIR/userconf.sh"
i18n_init

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
NATIVE="${OMARCHY_PATH:-/usr/share/omarchy}"
[[ -f "$CONFIG_HOME/hypr/hyprland.lua" && -f "$CONFIG_HOME/omarchy/shell.json" ]] || exit 0
for dependency in lua luac jq Hyprland; do
    command -v "$dependency" >/dev/null || err "session.validation_failed" "$dependency"
done
STAGE=$(mktemp -d)
trap 'rm -rf -- "$STAGE"' EXIT
mkdir -p "$STAGE/config/hypr" "$STAGE/data/os/hypr" "$STAGE/menu" "$STAGE/blocks"
cp "$SCRIPT_DIR/data/runtime.lua" "$STAGE/data/os/hypr/runtime.lua"
for file in "$CONFIG_HOME/hypr/"*.lua; do
    [[ -f "$file" && ! -L "$file" ]] || err "session.validation_failed" "$file"
    lua "$SCRIPT_DIR/data/clean.lua" "$file" "$STATE_HOME/os/hypr-blocks/${file##*/}" "$STAGE/blocks/${file##*/}" \
        > "$STAGE/config/hypr/${file##*/}" || err "session.validation_failed" "$file"
done
for file in Menu.qml MenuModel.js BarWidget.qml; do
    cp "$NATIVE/shell/plugins/menu/$file" "$STAGE/menu/$file"
done
[[ $(grep -Fc 'Style.space(300)), panel.width' "$STAGE/menu/Menu.qml") == 1 ]] || err "session.validation_failed" "menu width"
sed -i 's/Style.space(300)), panel.width/Style.space(360)), panel.width/' "$STAGE/menu/Menu.qml"
sed -i 's@/extensions/omarchy-menu.jsonc@/extensions/os-menu.json@' "$STAGE/menu/Menu.qml"
jq '.id = "os.menu" | .name = "OS menu" | .author = "OS" | .omarchy = {clonedFrom: "omarchy.menu"}' \
    "$NATIVE/shell/plugins/menu/manifest.json" > "$STAGE/menu/manifest.json"
jq -f "$SCRIPT_DIR/data/shell.jq" "$CONFIG_HOME/omarchy/shell.json" > "$STAGE/shell.json"
MENU_SOURCE="$CONFIG_HOME/omarchy/extensions/omarchy-menu.jsonc"
if [[ -f "$MENU_SOURCE" ]]; then
    jq -Rs 'gsub("(?m)^\\s*//[^\\n]*(\\n|$)"; "") | gsub(",(?<ending>\\s*[}\\]])"; .ending) | fromjson | (.items // .)' \
        "$MENU_SOURCE" > "$STAGE/personal-menu.json" || err "session.validation_failed" "$MENU_SOURCE"
else
    printf '{}\n' > "$STAGE/personal-menu.json"
fi
jq --slurpfile personal "$STAGE/personal-menu.json" \
    --arg bar "$(t session.menu_bar)" --arg show "$(t session.menu_show)" \
    --arg hide "$(t session.menu_hide)" --arg settings "$(t session.menu_settings)" \
    --arg position "$(t session.menu_position)" \
    '$personal[0] + (.bar.label = $bar | .bar.description = $bar | .["bar.show"].label = $show | .["bar.hide"].label = $hide | .["bar.settings"].label = $settings | .["bar.position"].label = $position)' \
    "$SCRIPT_DIR/data/menu.json" > "$STAGE/extension.json"
[[ -x /usr/lib/qt6/bin/qmlformat ]] || err "session.validation_failed" "qmlformat"
/usr/lib/qt6/bin/qmlformat -n "$STAGE/menu/Menu.qml" > /dev/null || err "session.validation_failed" "Menu.qml"
XDG_DATA_HOME="$STAGE/data" OS_HYPR_CONFIG_ROOT="$STAGE/config/hypr" \
    Hyprland --verify-config --config "$STAGE/config/hypr/hyprland.lua" > "$STAGE/validation.log" 2>&1 || {
        cat "$STAGE/validation.log"
        err "session.validation_failed" "Hyprland"
    }
grep -qx 'config ok' "$STAGE/validation.log" || { cat "$STAGE/validation.log"; err "session.validation_failed" Hyprland; }
install_user_file "$STAGE/data/os/hypr/runtime.lua" "$DATA_HOME/os/hypr/runtime.lua"
if [[ -f "$DATA_HOME/omarchy/herdr-keybindings-menu" ]]; then
    install_user_file "$DATA_HOME/omarchy/herdr-keybindings-menu" "$DATA_HOME/os/herdr-keybindings-menu" 755
fi
for file in "$STAGE/config/hypr/"*.lua; do
    [[ "${file##*/}" == hyprland.lua ]] && continue
    install_user_file "$file" "$CONFIG_HOME/hypr/${file##*/}"
done
install_user_file "$STAGE/config/hypr/hyprland.lua" "$CONFIG_HOME/hypr/hyprland.lua"
for file in "$STAGE/blocks/"*.lua; do
    install_user_file "$file" "$STATE_HOME/os/hypr-blocks/${file##*/}" 600
done
for file in Menu.qml MenuModel.js BarWidget.qml manifest.json; do
    install_user_file "$STAGE/menu/$file" "$CONFIG_HOME/omarchy/plugins/os.menu/$file"
done
install_user_file "$STAGE/extension.json" "$CONFIG_HOME/omarchy/extensions/os-menu.json" 600
install_user_file "$STAGE/shell.json" "$CONFIG_HOME/omarchy/shell.json" 600
mkdir -p "$STATE_HOME/omarchy/toggles"
install_user_content "$STATE_HOME/omarchy/toggles/bar-off" 600 < /dev/null
log "session.configured"
