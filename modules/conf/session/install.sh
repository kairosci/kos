#!/usr/bin/env bash
set -euo pipefail

SessionInstaller::run() {
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
[[ -f "$CONFIG_HOME/hypr/hyprland.lua" ]] || exit 0
migrate_user_config_dir "$HOME"
[[ -f "$CONFIG_HOME/os/shell.json" ]] || exit 0
for dependency in lua jq Hyprland qs; do
    command -v "$dependency" >/dev/null || err "session.validation_failed" "$dependency"
done
STAGE=$(mktemp -d)
trap 'rm -rf -- "$STAGE"' EXIT
mkdir -p "$STAGE/config/hypr" "$STAGE/data/os/hypr" "$STAGE/data/os/session/data" "$STAGE/plugins" "$STAGE/blocks"
jq -e '.menu.width >= 320 and .menu.width <= 1000' "$SCRIPT_DIR/data/policy.json" > /dev/null || err "session.validation_failed" policy.json
jq --arg runtime "$NATIVE" '.runtime = $runtime' "$SCRIPT_DIR/data/policy.json" > "$STAGE/data/os/session/data/policy.json"
POLICY="$STAGE/data/os/session/data/policy.json"
source "$SCRIPT_DIR/scripts/clock.sh"
local -A clock_widget=()
ClockWidget::new clock_widget "$SCRIPT_DIR" "$STAGE" "$POLICY"
ClockWidget::stage clock_widget
cp "$SCRIPT_DIR/scripts/runtime.lua" "$STAGE/data/os/hypr/runtime.lua"
for file in "$CONFIG_HOME/hypr/"*.lua; do
    [[ -f "$file" && ! -L "$file" ]] || err "session.validation_failed" "$file"
    previous="$STATE_HOME/os/hypr-blocks/${file##*/}.json"
    if [[ ! -f "$previous" && -f "$STATE_HOME/os/hypr-blocks/${file##*/}" ]]; then
        previous="$STAGE/blocks/legacy-${file##*/}.json"
        lua "$SCRIPT_DIR/scripts/legacy-state.lua" "$STATE_HOME/os/hypr-blocks/${file##*/}" > "$previous"
    fi
    bash "$SCRIPT_DIR/scripts/clean-hypr.sh" "$file" "$previous" "$STAGE/blocks/${file##*/}.json" \
        > "$STAGE/config/hypr/${file##*/}" || err "session.validation_failed" "$file"
done
: > "$STAGE/session-bindings.lua"
while IFS=$'\t' read -r key label command; do
    label=$(t "$label")
    jq -nr --arg key "$key" --arg label "$label" --arg command "$command" \
        '"hl.unbind(" + ($key|@json) + ")\no.bind(" + ($key|@json) + ", " + ($label|@json) + ", " + ($command|@json) + ")"' >> "$STAGE/session-bindings.lua"
done < <(jq -r '.[] | [.key,.labelKey,.command] | @tsv' "$SCRIPT_DIR/data/bindings.json")
bash "$SCRIPT_DIR/scripts/clean-hypr.sh" "$STAGE/config/hypr/bindings.lua" "$STAGE/blocks/bindings.lua.json" "$STAGE/blocks/bindings-next.lua.json" 'os session controls' "$STAGE/session-bindings.lua" > "$STAGE/bindings.lua"
mv "$STAGE/bindings.lua" "$STAGE/config/hypr/bindings.lua"
mv "$STAGE/blocks/bindings-next.lua.json" "$STAGE/blocks/bindings.lua.json"

MENU_ID=$(jq -r '.menu.id' "$POLICY")
mkdir -p "$STAGE/plugins/$MENU_ID"
lua "$SCRIPT_DIR/scripts/prepare-menu.lua" "$NATIVE/shell/plugins/menu/Menu.qml" "$SCRIPT_DIR/qml/MenuSupport.qml.inc" > "$STAGE/plugins/$MENU_ID/Menu.qml"
cp "$NATIVE/shell/plugins/menu/MenuModel.js" "$STAGE/plugins/$MENU_ID/"
cp "$SCRIPT_DIR/qml/AppCatalog.qml" "$SCRIPT_DIR/qml/SessionI18n.qml" "$SCRIPT_DIR/qml/qmldir" "$STAGE/plugins/$MENU_ID/"
{ printf 'import qs.Ui\n'; cat "$NATIVE/shell/Ui/ConfirmDialog.qml"; } > "$STAGE/plugins/$MENU_ID/ControlConfirmDialog.qml"
jq --slurpfile policy "$POLICY" '.id = $policy[0].menu.id | .name = $policy[0].menu.name | .author = "OS" | .kinds = ["menu"] | .entryPoints = {menu: .entryPoints.menu} | .omarchy = {clonedFrom: .id} | .omarchy.clonedFrom = "omarchy.menu" | del(.barWidget)' \
    "$NATIVE/shell/plugins/menu/manifest.json" > "$STAGE/plugins/$MENU_ID/manifest.json"
for retired in os.controls os.audio os.network os.bluetooth os.monitor os.power os.clock os.weather os.media os.tray; do
    rm -rf "$CONFIG_HOME/os/plugins/$retired"
done
jq --slurpfile policy "$POLICY" --slurpfile defaults "$SCRIPT_DIR/data/shell.json" -f "$SCRIPT_DIR/scripts/shell.jq" \
    "$CONFIG_HOME/os/shell.json" > "$STAGE/shell.json"
lua "$SCRIPT_DIR/scripts/jsonc.lua" "$NATIVE/default/omarchy/omarchy-menu.jsonc" \
    | jq --slurpfile policy "$POLICY" -f "$SCRIPT_DIR/scripts/filter-menu.jq" > "$STAGE/data/os/session/data/menu.json"
if [[ -f "$CONFIG_HOME/os/extensions/omarchy-menu.jsonc" ]]; then
    lua "$SCRIPT_DIR/scripts/jsonc.lua" "$CONFIG_HOME/os/extensions/omarchy-menu.jsonc" | jq --slurpfile policy "$POLICY" -f "$SCRIPT_DIR/scripts/filter-menu.jq" > "$STAGE/personal-menu.json"
else
    printf '{}\n' > "$STAGE/personal-menu.json"
fi
if [[ -f "$CONFIG_HOME/os/extensions/os-menu.json" ]]; then
    lua "$SCRIPT_DIR/scripts/jsonc.lua" "$CONFIG_HOME/os/extensions/os-menu.json" \
        | jq --slurpfile policy "$POLICY" -f "$SCRIPT_DIR/scripts/filter-menu.jq" > "$STAGE/previous-menu.json"
    jq -s '.[0] * .[1]' "$STAGE/personal-menu.json" "$STAGE/previous-menu.json" > "$STAGE/personal-next.json"
    jq 'with_entries(select(.key | startswith("controls") | not))' "$STAGE/personal-next.json" > "$STAGE/personal-menu.json"
fi
cp "$STAGE/personal-menu.json" "$STAGE/extension.json"
cp "$NATIVE/default/omarchy/launcher.hides" "$STAGE/data/os/session/data/launcher.hides"
jq -n --arg language "$I18N_LANG" --slurpfile catalogue "$SCRIPT_DIR/data/locales/$I18N_LANG.json" \
    '{language:$language,messages:$catalogue[0].messages,patterns:$catalogue[0].patterns,folded:($catalogue[0].messages | to_entries | map({key:(.key|ascii_downcase),value:.value}) | from_entries)}' \
    > "$STAGE/data/os/session/data/translations.json"
for file in "$STAGE/data/os/session/data/menu.json" "$STAGE/extension.json"; do
    jq --slurpfile catalogue "$SCRIPT_DIR/data/locales/$I18N_LANG.json" \
        'with_entries(.value |= (if type == "object" then (.label = ($catalogue[0].messages[.label] // .label) | if .title then .title = ($catalogue[0].messages[.title] // .title) else . end) else . end))' \
        "$file" > "$STAGE/localized-menu.json"
    mv "$STAGE/localized-menu.json" "$file"
done
while IFS= read -r -d '' file; do
    case "$file" in
        */SessionI18n.qml|*/ClockWidget.qml) mode=clean ;;
        *.qml) mode=localize ;;
        *) mode=clean ;;
    esac
    lua "$SCRIPT_DIR/scripts/prepare-qml.lua" "$file" "$mode" . > "$STAGE/component.next"
    mv "$STAGE/component.next" "$file"
done < <(find "$STAGE/plugins" -type f \( -name '*.qml' -o -name '*.js' \) -print0)
[[ -x /usr/lib/qt6/bin/qmlformat ]] || err "session.validation_failed" qmlformat
while IFS= read -r -d '' file; do
    /usr/lib/qt6/bin/qmlformat -n "$file" > /dev/null || err "session.validation_failed" "$file"
done < <(find "$STAGE/plugins" -name '*.qml' -print0)
mkdir -p "$STAGE/validator"
cp "$SCRIPT_DIR/qml/Validate.qml" "$STAGE/validator/shell.qml"
for directory in Commons Ui services; do ln -s "$NATIVE/shell/$directory" "$STAGE/validator/$directory"; done
find "$STAGE/plugins" -name '*.qml' -print0 | jq -Rs 'split("\u0000") | map(select(length > 0))' > "$STAGE/components.json"
session_display="${WAYLAND_DISPLAY:-}"
if session_environment=$(systemctl --user show-environment); then
    while IFS= read -r entry; do
        case "$entry" in WAYLAND_DISPLAY=*) session_display="${entry#WAYLAND_DISPLAY=}" ;; esac
    done <<< "$session_environment"
fi
session_socket="$session_display"
[[ "$session_display" == /* ]] || session_socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/$session_display"
if [[ -n "$session_display" && -S "$session_socket" ]]; then
    if ! env QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$session_display" OMARCHY_PATH="$NATIVE" OS_SESSION_COMPONENTS="$STAGE/components.json" \
        timeout 25 qs -p "$STAGE/validator" > "$STAGE/qml-validation.log" 2>&1 \
        || ! grep -q 'session-components-valid' "$STAGE/qml-validation.log"; then
        cat "$STAGE/qml-validation.log"
        err "session.validation_failed" QML
    fi
elif [[ "${OS_SESSION_REQUIRE_ENGINE:-0}" == 1 ]]; then
    err "session.validation_failed" Wayland
else
    warn "session.engine_deferred"
fi
XDG_DATA_HOME="$STAGE/data" OS_HYPR_CONFIG_ROOT="$STAGE/config/hypr" \
    Hyprland --verify-config --config "$STAGE/config/hypr/hyprland.lua" > "$STAGE/validation.log" 2>&1 || {
        cat "$STAGE/validation.log"
        err "session.validation_failed" Hyprland
    }
grep -qx 'config ok' "$STAGE/validation.log" || { cat "$STAGE/validation.log"; err "session.validation_failed" Hyprland; }
if [[ ! -f "$STATE_HOME/os/session/original-shell.json" ]]; then
    install_user_file "$CONFIG_HOME/os/shell.json" "$STATE_HOME/os/session/original-shell.json" 600
fi
install_user_file "$STAGE/data/os/hypr/runtime.lua" "$DATA_HOME/os/hypr/runtime.lua"
if [[ -f "$DATA_HOME/omarchy/herdr-keybindings-menu" ]]; then
    install_user_file "$DATA_HOME/omarchy/herdr-keybindings-menu" "$DATA_HOME/os/herdr-keybindings-menu" 755
fi
for file in "$STAGE/config/hypr/"*.lua; do
    [[ "${file##*/}" == hyprland.lua ]] && continue
    install_user_file "$file" "$CONFIG_HOME/hypr/${file##*/}"
done
install_user_file "$STAGE/config/hypr/hyprland.lua" "$CONFIG_HOME/hypr/hyprland.lua"
for file in "$STAGE/blocks/"*.lua.json; do
    install_user_file "$file" "$STATE_HOME/os/hypr-blocks/${file##*/}" 600
    legacy="$STATE_HOME/os/hypr-blocks/${file##*/}"
    legacy="${legacy%.json}"
    if [[ -f "$legacy" ]]; then
        install_user_file "$legacy" "$STATE_HOME/os/session/retired-blocks/${legacy##*/}" 600
        rm "$legacy"
    fi
done
for file in "$STAGE/data/os/session/data/"*; do
    install_user_file "$file" "$DATA_HOME/os/session/data/${file##*/}" 600
done
while IFS= read -r -d '' file; do
    install_user_file "$file" "$CONFIG_HOME/os/plugins/${file#"$STAGE/plugins/"}"
done < <(find "$STAGE/plugins" -type f ! -name manifest.json -print0)
while IFS= read -r -d '' file; do
    install_user_file "$file" "$CONFIG_HOME/os/plugins/${file#"$STAGE/plugins/"}"
done < <(find "$STAGE/plugins" -name manifest.json -print0)
install_user_file "$STAGE/extension.json" "$CONFIG_HOME/os/extensions/os-menu.json" 600
install_user_file "$STAGE/shell.json" "$CONFIG_HOME/os/shell.json" 600
install_user_file "$SCRIPT_DIR/scripts/environment.sh" "$DATA_HOME/os/session/scripts/environment.sh" 600
for file in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [[ -f "$file" ]] || continue
    remove_shell_block "$file" '# os quickshell default (managed)' '# end os quickshell default (managed)'
    install_user_line "$file" <<'SHELL'
source "${XDG_DATA_HOME:-$HOME/.local/share}/os/session/scripts/environment.sh"
SHELL
done
jq -r '"QS_CONFIG_PATH=" + .runtime + "/shell"' "$POLICY" > "$STAGE/environment.conf"
install_user_file "$STAGE/environment.conf" "$CONFIG_HOME/environment.d/60-os-quickshell.conf" 600
if [[ -L "$CONFIG_HOME/quickshell/default" && "$(readlink -f "$CONFIG_HOME/quickshell/default")" == "$(readlink -f "$NATIVE/shell")" ]]; then
    rm "$CONFIG_HOME/quickshell/default"
fi
mkdir -p "$STATE_HOME/omarchy/toggles"
install_user_content "$STATE_HOME/omarchy/toggles/bar-off" 600 < /dev/null
log "session.configured"
}

SessionInstaller::run "$@"
