#!/usr/bin/env bash

Os::modules::conf::zed::theme_sh::run() {
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
BOOT="${OS_I18N_BOOT:-${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/hooks/i18n/i18n-boot.sh}"
[[ -f "$BOOT" ]] || BOOT="$PROJECT_DIR/scripts/lib/i18n-boot.sh"
OS_I18N_DIR="$(dirname "$BOOT")/messages"
# shellcheck source=/dev/null
source "$BOOT"
USERCONF="$SCRIPT_DIR/userconf.sh"
[[ -f "$USERCONF" ]] || USERCONF="$PROJECT_DIR/scripts/lib/userconf.sh"
# shellcheck source=/dev/null
source "$USERCONF"
COLORS="${OS_THEME_COLORS:-$HOME/.local/state/omarchy/current/theme/colors.toml}"
[[ -r "$COLORS" ]] || err "hooks.gtk_palette_failed" "$COLORS"
CONFIG="${OS_ZED_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/zed}"
PALETTE=$(awk -F '"' '/^[a-z_]+[[:space:]]*=/ { key=$1; sub(/[[:space:]]*=.*/, "", key); print key "\t" $2 }' "$COLORS" | jq -Rn '[inputs | split("\t") | {key: .[0], value: .[1]}] | from_entries')
jq -e 'has("mode") and (.mode == "dark" or .mode == "light") and ([.background, .foreground, .accent, .selection, .muted, .red, .green, .blue, .yellow, .cyan, .magenta] | all(type == "string" and test("^#[0-9a-fA-F]{6}$")))' <<< "$PALETTE" >/dev/null || err "hooks.gtk_palette_failed" "$COLORS"
STYLE=$(jq -n --argjson p "$PALETTE" '
    def color($c): {color: $c};
    {
        "background": $p.background, "surface.background": $p.background,
        "elevated_surface.background": ($p.lighter_background // $p.background),
        "panel.background": ($p.dark_background // $p.background),
        "toolbar.background": $p.background, "title_bar.background": $p.background,
        "title_bar.inactive_background": $p.background, "status_bar.background": $p.background,
        "tab_bar.background": $p.background, "tab.active_background": $p.background,
        "tab.inactive_background": ($p.dark_background // $p.background),
        "text": $p.foreground, "text.muted": $p.muted, "text.accent": $p.accent,
        "icon": $p.foreground, "icon.muted": $p.muted, "icon.accent": $p.accent,
        "border": $p.muted, "border.focused": $p.accent, "border.selected": $p.accent,
        "element.background": $p.background, "element.hover": $p.selection,
        "element.selected": $p.selection, "element.active": $p.selection,
        "editor.background": $p.background, "editor.foreground": $p.foreground,
        "editor.gutter.background": $p.background, "editor.line_number": $p.muted,
        "editor.active_line_number": $p.accent, "editor.active_line.background": ($p.lighter_background // $p.background),
        "editor.selection.background": $p.selection, "editor.wrap_guide": $p.muted,
        "players": [{cursor: $p.accent, background: $p.accent, selection: $p.selection}],
        "syntax": {comment: color($p.muted), keyword: color($p.magenta), string: color($p.green),
            number: color($p.orange // $p.yellow), function: color($p.blue), type: color($p.yellow),
            variable: color($p.foreground), constant: color($p.cyan), operator: color($p.accent)},
        "error": $p.red, "warning": $p.yellow, "success": $p.green,
        "terminal.background": $p.background, "terminal.foreground": $p.foreground
    }
')
if [[ -f "$CONFIG/settings.json" ]]; then
    SETTINGS=$(cat "$CONFIG/settings.json")
else
    SETTINGS='{}'
fi
SETTINGS=$(jq --argjson p "$PALETTE" --argjson style "$STYLE" '
    .theme = {mode: $p.mode, dark: "One Dark", light: "One Light"} |
    .theme_overrides = ((.theme_overrides // {}) * {"One Dark": $style, "One Light": $style})
' <<< "$SETTINGS")
install_user_content "$CONFIG/settings.json" 644 preserve-inode <<< "$SETTINGS"
for retired_theme in "$CONFIG/themes/os.json" "$CONFIG"/themes/os-*.json; do
    [[ -f "$retired_theme" ]] || continue
    if jq -e '.author == "os" and (.themes | length == 1) and (.themes[0].name | startswith("OS "))' "$retired_theme" >/dev/null; then
        [[ -e "$retired_theme.bak" ]] || cp -- "$retired_theme" "$retired_theme.bak"
        rm -f -- "$retired_theme"
    fi
done

}

Os::modules::conf::zed::theme_sh::run "$@"
