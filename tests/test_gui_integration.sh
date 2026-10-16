#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home" XDG_CONFIG_HOME="$SANDBOX/config" XDG_DATA_HOME="$SANDBOX/data" XDG_STATE_HOME="$SANDBOX/state" XDG_BIN_HOME="$SANDBOX/bin" OS_LANG=en
export OS_I18N_BOOT="$PROJECT_DIR/scripts/lib/i18n-boot.sh"
mkdir -p "$HOME" "$SANDBOX/bin" "$SANDBOX/project with spaces"
export PATH="$SANDBOX/bin:$PATH" GUI_TEST_ARGS="$SANDBOX/arguments"
cat > "$SANDBOX/bin/gsettings" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$GUI_TEST_ARGS"
[[ "$1" != get ]] || printf "'Sans 11'\n"
MOCK
cat > "$SANDBOX/bin/update-desktop-database" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
exit 0
MOCK
chmod 755 "$SANDBOX/bin/"*

test_section "Graphical Application Integration"
assert_false "missing configuration source cannot report successful installation" 'install_user_file "$SANDBOX/missing" "$SANDBOX/destination"'
printf 'mode = "dark"\nbackground = "#101010"\nforeground = "#eeeeee"\naccent = "#abcdef"\nselection = "#303030"\nmuted = "#777777"\nred = "#ff0000"\ngreen = "#00ff00"\nblue = "#0000ff"\nyellow = "#ffff00"\ncyan = "#00ffff"\nmagenta = "#ff00ff"\n' > "$SANDBOX/palette.toml"
export OS_THEME_COLORS="$SANDBOX/palette.toml"
assert_true "animation policy disables tearing and inherited workspace motion" "lua '$SCRIPT_DIR/animation-policy.lua' '$PROJECT_DIR/modules/conf/gtk/data/tiling.lua'"
assert_file_contains_literal "floating Hyprland windows use monitor-bounded dimensions" "$PROJECT_DIR/modules/conf/gtk/data/tiling.lua" 'o.window({ float = true }, { max_size = { "monitor_w-2", "monitor_h-2" } })'
assert_file_not_contains "automatic tiled layout remains unconstrained by the floating size cap" "$PROJECT_DIR/modules/conf/gtk/data/tiling.lua" 'size_limits_tiled = true'
assert_file_contains_literal "GTK portal file picker stays centered within the monitor" "$PROJECT_DIR/modules/conf/gtk/data/tiling.lua" 'o.window("xdg-desktop-portal-gtk", { center = true, max_size = { "monitor_w-2", "monitor_h-2" } })'
assert_true "Zed native configuration installs" "bash '$PROJECT_DIR/modules/conf/zed/install.sh'"
assert_true "Zed uses native project preferences" "jq -e '.restore_on_startup == \"last_workspace\" and .project_panel.git_status == true and .terminal.shell == \"system\"' '$XDG_CONFIG_HOME/zed/settings.json'"
assert_true "Zed settings installation is idempotent" "before=\$(sha256sum '$XDG_CONFIG_HOME/zed/settings.json'); bash '$PROJECT_DIR/modules/conf/zed/install.sh'; [[ \"\$before\" == \"\$(sha256sum '$XDG_CONFIG_HOME/zed/settings.json')\" ]]"
mkdir -p "$SANDBOX/invalid-zed"
printf '{invalid\n' > "$SANDBOX/invalid-zed/settings.json"
assert_false "invalid settings stop the producer before publishing Zed configuration" "OS_ZED_CONFIG_DIR='$SANDBOX/invalid-zed' bash '$PROJECT_DIR/modules/conf/zed/install.sh'"
assert_file_contains_literal "failed settings generation preserves the previous file" "$SANDBOX/invalid-zed/settings.json" '{invalid'
assert_true "Nautilus native settings install" "lua '$PROJECT_DIR/tests/lua/apply_settings.lua' '$PROJECT_DIR' nautilus"
mkdir -p "$XDG_CONFIG_HOME/hypr" "$XDG_CONFIG_HOME/gtk-4.0"
printf 'custom_setting = true\n' > "$XDG_CONFIG_HOME/hypr/hyprland.lua"
printf '.personal { color: red; }\n' > "$XDG_CONFIG_HOME/gtk-4.0/gtk.css"
mkdir -p "$XDG_CONFIG_HOME/omarchy/hooks/theme-set.d" "$XDG_CONFIG_HOME/omarchy"
printf '%s\n' '#!/bin/bash' 'exec /usr/bin/python "$HOME/.config/omarchy/gtk-unified.py"' > "$XDG_CONFIG_HOME/omarchy/hooks/theme-set.d/zz-unified-icons"
printf '%s\n' 'legacy generator' > "$XDG_CONFIG_HOME/omarchy/gtk-unified.py"
assert_true "GTK integration installs through the user installer" "bash '$PROJECT_DIR/modules/conf/gtk/install.sh'"
assert_file_contains_literal "GTK installer enables native toolkit animations" "$GUI_TEST_ARGS" 'set org.gnome.desktop.interface enable-animations true'
assert_file_contains_literal "GTK installer preserves personal Hyprland settings" "$XDG_CONFIG_HOME/hypr/hyprland.lua" 'custom_setting = true'
assert_true "GTK installer retires the competing Python icon hook with a backup" "[[ ! -e '$XDG_CONFIG_HOME/omarchy/hooks/theme-set.d/zz-unified-icons' && ! -e '$XDG_CONFIG_HOME/omarchy/gtk-unified.py' ]] && grep -qx 'legacy generator' '$XDG_CONFIG_HOME/omarchy/migrations/gtk-unified/generator.py'"
assert_true "GTK installer provisions the canonical terminal icon assets" "cmp '$PROJECT_DIR/modules/conf/gtk/data/nerd-icons/aliases.tsv' '$XDG_CONFIG_HOME/omarchy/nerd-icons/aliases.tsv'"
assert_true "GTK integration is idempotent" "before=\$(sha256sum '$XDG_CONFIG_HOME/hypr/hyprland.lua' '$XDG_CONFIG_HOME/hypr/os-gtk.lua'); bash '$PROJECT_DIR/modules/conf/gtk/install.sh'; [[ \"\$before\" == \"\$(sha256sum '$XDG_CONFIG_HOME/hypr/hyprland.lua' '$XDG_CONFIG_HOME/hypr/os-gtk.lua')\" ]]"
printf 'mode = "dark"\nbackground = "#101010"\nforeground = "#eeeeee"\naccent = "#abcdef"\nselection = "#303030"\nmuted = "#777777"\nred = "#ff0000"\ngreen = "#00ff00"\nblue = "#0000ff"\nyellow = "#ffff00"\ncyan = "#00ffff"\nmagenta = "#ff00ff"\n' > "$SANDBOX/palette.toml"
export OS_THEME_NAME=test OS_THEME_COLORS="$SANDBOX/palette.toml"
mkdir -p "$XDG_CONFIG_HOME/zed/themes"
printf '%s\n' '{"author":"os","themes":[{"name":"OS retired"}]}' > "$XDG_CONFIG_HOME/zed/themes/os-retired.json"
printf '%s\n' '{"author":"personal","themes":[{"name":"Personal"}]}' > "$XDG_CONFIG_HOME/zed/themes/os-personal.json"
assert_true "GTK flat palette generation succeeds" "bash '$PROJECT_DIR/hooks/theme-set.d/gtk-theme'"
assert_file_contains_literal "GTK preserves personal CSS" "$XDG_CONFIG_HOME/gtk-4.0/gtk.css" '.personal { color: red; }'
assert_true "GTK flat palette generation is idempotent" "before=\$(sha256sum '$XDG_CONFIG_HOME/gtk-4.0/gtk.css' '$XDG_CONFIG_HOME/gtk-4.0/os.css'); bash '$PROJECT_DIR/hooks/theme-set.d/gtk-theme'; [[ \"\$before\" == \"\$(sha256sum '$XDG_CONFIG_HOME/gtk-4.0/gtk.css' '$XDG_CONFIG_HOME/gtk-4.0/os.css')\" ]]"
assert_file_contains_literal "GTK headerbars use the palette background" "$XDG_CONFIG_HOME/gtk-4.0/os.css" '--headerbar-bg-color: #101010;'
assert_file_contains_literal "GTK cards use the palette background" "$XDG_CONFIG_HOME/gtk-4.0/os.css" '--card-bg-color: #101010;'
assert_true "Zed palette generates and selects a native theme" "bash '$PROJECT_DIR/modules/conf/zed/theme.sh'"
assert_false "Zed removes retired generated themes" "test -e '$XDG_CONFIG_HOME/zed/themes/os-retired.json'"
assert_true "Zed preserves personal themes" "test -e '$XDG_CONFIG_HOME/zed/themes/os-personal.json'"
assert_true "Zed native overrides use the palette and preserve editor preferences" "jq -e '.theme.mode == \"dark\" and .theme_overrides[\"One Dark\"][\"editor.background\"] == \"#101010\" and .theme_overrides[\"One Dark\"].syntax.keyword.color == \"#ff00ff\" and .disable_ai == true' '$XDG_CONFIG_HOME/zed/settings.json'"
assert_true "Zed theme synchronization is idempotent" "before=\$(sha256sum '$XDG_CONFIG_HOME/zed/settings.json'); bash '$PROJECT_DIR/modules/conf/zed/theme.sh'; [[ \"\$before\" == \"\$(sha256sum '$XDG_CONFIG_HOME/zed/settings.json')\" ]]"
sed -i 's/"dark"/"light"/; s/#101010/#f0f0f0/' "$OS_THEME_COLORS"
ZED_SETTINGS_INODE=$(stat -c %i "$XDG_CONFIG_HOME/zed/settings.json")
assert_true "Zed follows a subsequent light palette through live settings" "bash '$PROJECT_DIR/modules/conf/zed/theme.sh' && jq -e '.theme.mode == \"light\" and .theme_overrides[\"One Light\"][\"editor.background\"] == \"#f0f0f0\"' '$XDG_CONFIG_HOME/zed/settings.json'"
assert_true "palette changes preserve Zed's watched settings inode" '[[ $(stat -c %i "$XDG_CONFIG_HOME/zed/settings.json") == "$ZED_SETTINGS_INODE" ]]'
assert_true "invalid watched write mode cannot replace existing settings" '! install_user_content "$XDG_CONFIG_HOME/zed/settings.json" 644 invalid <<< "{}" && [[ $(stat -c %i "$XDG_CONFIG_HOME/zed/settings.json") == "$ZED_SETTINGS_INODE" ]]'
sed -i 's/#f0f0f0/invalid/' "$OS_THEME_COLORS"
assert_false "invalid GTK palette fails before replacing CSS" "bash '$PROJECT_DIR/hooks/theme-set.d/gtk-theme'"
assert_file_contains_literal "invalid GTK palette preserves previous CSS" "$XDG_CONFIG_HOME/gtk-4.0/os.css" '--window-bg-color: #101010;'
assert_false "invalid Zed palette fails before replacing the theme" "bash '$PROJECT_DIR/modules/conf/zed/theme.sh'"
assert_true "invalid palette preserves the previous Zed theme" "jq -e '.theme_overrides[\"One Light\"][\"editor.background\"] == \"#f0f0f0\"' '$XDG_CONFIG_HOME/zed/settings.json'"
unset OS_THEME_NAME OS_THEME_COLORS
mkdir -p "$XDG_CONFIG_HOME/omarchy"
printf '%s\n' '{"bar":{"layout":{"right":[{"id":"omarchy.agents","refreshIntervalSec":120,"providers":{"claude":{"enabled":true},"codex":{"enabled":true},"fireworks":{"enabled":false}}}] }},"idle":{"lock":321}}' > "$XDG_CONFIG_HOME/omarchy/shell.json"
assert_true "Agents installer disables only the Claude provider" "bash '$PROJECT_DIR/modules/conf/agents/install.sh' && jq -e '.bar.layout.right[0].providers.claude.enabled == false and .bar.layout.right[0].providers.codex.enabled == true and .bar.layout.right[0].providers.fireworks.enabled == false and .bar.layout.right[0].refreshIntervalSec == 120 and .idle.lock == 321' '$XDG_CONFIG_HOME/omarchy/shell.json'"
assert_true "Agents configuration is idempotent" "before=\$(sha256sum '$XDG_CONFIG_HOME/omarchy/shell.json'); bash '$PROJECT_DIR/modules/conf/agents/install.sh'; [[ \"\$before\" == \"\$(sha256sum '$XDG_CONFIG_HOME/omarchy/shell.json')\" ]]"
printf '%s\n' '{"bar":{"layout":{"left":["omarchy.agents"],"right":[]}}}' > "$XDG_CONFIG_HOME/omarchy/shell.json"
assert_true "Agents installer handles string widget entries" "bash '$PROJECT_DIR/modules/conf/agents/install.sh' && jq -e '.bar.layout.left[0].id == \"omarchy.agents\" and .bar.layout.left[0].providers.claude.enabled == false' '$XDG_CONFIG_HOME/omarchy/shell.json'"
printf '%s\n' '{"idle":{"lock":123}}' > "$XDG_CONFIG_HOME/omarchy/shell.json"
assert_true "Agents installer preserves a configuration without the widget" "bash '$PROJECT_DIR/modules/conf/agents/install.sh' && jq -e '.bar == null and .idle.lock == 123' '$XDG_CONFIG_HOME/omarchy/shell.json'"
printf '%s\n' '{invalid' > "$XDG_CONFIG_HOME/omarchy/shell.json"
assert_false "Agents installer rejects malformed configuration" "bash '$PROJECT_DIR/modules/conf/agents/install.sh'"
assert_file_contains_literal "Agents failure preserves the original configuration" "$XDG_CONFIG_HOME/omarchy/shell.json" '{invalid'

test_summary
