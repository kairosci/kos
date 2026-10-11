#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
BOOT="${KOS_I18N_BOOT:-${XDG_CONFIG_HOME:-$HOME/.config}/kos/hooks/i18n/i18n-boot.sh}"
[[ -f "$BOOT" ]] || BOOT="$PROJECT_DIR/scripts/lib/i18n-boot.sh"
KOS_I18N_DIR="$(dirname "$BOOT")/messages"
# shellcheck source=/dev/null
source "$BOOT"
USERCONF="$SCRIPT_DIR/userconf.sh"
[[ -f "$USERCONF" ]] || USERCONF="$PROJECT_DIR/scripts/lib/userconf.sh"
# shellcheck source=/dev/null
source "$USERCONF"
COLORS="${KOS_THEME_COLORS:-$HOME/.local/state/kos/current/theme/colors.toml}"
[[ -r "$COLORS" ]] || exit 0
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/zed"
PALETTE=$(awk -F '"' '/^[a-z_]+[[:space:]]*=/ { key=$1; sub(/[[:space:]]*=.*/, "", key); print key "\t" $2 }' "$COLORS" | jq -Rn '[inputs | split("\t") | {key: .[0], value: .[1]}] | from_entries')
jq -e 'has("mode") and (.mode == "dark" or .mode == "light") and ([.background, .foreground, .accent, .selection, .muted, .red, .green, .blue, .yellow, .cyan, .magenta] | all(type == "string" and test("^#[0-9a-fA-F]{6}$")))' <<< "$PALETTE" >/dev/null || err "hooks.gtk_palette_failed" "$COLORS"
THEME_NAME="${KOS_THEME_NAME:-}"
if [[ -z "$THEME_NAME" && -r "$HOME/.local/state/kos/current/theme.name" ]]; then
    THEME_NAME=$(cat "$HOME/.local/state/kos/current/theme.name")
fi
[[ -n "$THEME_NAME" ]] || THEME_NAME=$(sha256sum "$COLORS" | cut -c1-12)
NAME="Kos $THEME_NAME"
SLUG=$(printf '%s' "$THEME_NAME" | tr '[:upper:] ' '[:lower:]-')
[[ "$SLUG" =~ ^[a-z0-9-]+$ ]] || err "hooks.gtk_palette_failed" "$COLORS"
jq -n --arg name "$NAME" --argjson p "$PALETTE" '
    def color($c): {color: $c};
    {name: $name, author: "kos", themes: [{name: $name, appearance: $p.mode, style: {
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
    }}]}
' | install_user_content "$CONFIG/themes/kos.json"
if [[ -f "$CONFIG/settings.json" ]]; then
    SETTINGS=$(jq --arg name "$NAME" '.theme = $name' "$CONFIG/settings.json")
else
    SETTINGS=$(jq -n --arg name "$NAME" '{theme: $name}')
fi
install_user_content "$CONFIG/settings.json" <<< "$SETTINGS"
for retired_theme in "$CONFIG"/themes/kos-*.json; do
    [[ -f "$retired_theme" ]] || continue
    if jq -e '.author == "kos" and (.themes | length == 1) and (.themes[0].name | startswith("Kos "))' "$retired_theme" >/dev/null; then
        rm -f -- "$retired_theme"
    fi
done
