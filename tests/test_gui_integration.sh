#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home" XDG_CONFIG_HOME="$SANDBOX/config" XDG_DATA_HOME="$SANDBOX/data" XDG_STATE_HOME="$SANDBOX/state" XDG_BIN_HOME="$SANDBOX/bin" OMACONF_LANG=en
export OMACONF_I18N_BOOT="$PROJECT_DIR/scripts/lib/i18n-boot.sh"
mkdir -p "$HOME" "$SANDBOX/bin" "$SANDBOX/project with spaces"
export PATH="$SANDBOX/bin:$PATH" GUI_TEST_ARGS="$SANDBOX/arguments"
cat > "$SANDBOX/bin/gsettings" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" != get ]] || printf "'Sans 11'\n"
MOCK
cat > "$SANDBOX/bin/update-desktop-database" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
exit 0
MOCK
chmod 755 "$SANDBOX/bin/"*

test_section "Graphical Application Integration"
assert_true "animation policy disables tearing and inherited workspace motion" "lua '$SCRIPT_DIR/animation-policy.lua' '$PROJECT_DIR/conf/gtk/data/tiling.lua'"
assert_true "Zed native configuration installs" "bash '$PROJECT_DIR/conf/zed/install.sh'"
assert_true "Zed uses native project preferences" "jq -e '.restore_on_startup == \"last_workspace\" and .project_panel.git_status == true and .terminal.shell == \"system\"' '$XDG_CONFIG_HOME/zed/settings.json'"
assert_true "Zed settings installation is idempotent" "before=\$(sha256sum '$XDG_CONFIG_HOME/zed/settings.json'); bash '$PROJECT_DIR/conf/zed/install.sh'; [[ \"\$before\" == \"\$(sha256sum '$XDG_CONFIG_HOME/zed/settings.json')\" ]]"
assert_true "Nautilus native settings install" "bash '$PROJECT_DIR/conf/nautilus/install.sh'"
mkdir -p "$XDG_CONFIG_HOME/hypr" "$XDG_CONFIG_HOME/gtk-4.0"
printf 'custom_setting = true\n' > "$XDG_CONFIG_HOME/hypr/hyprland.lua"
printf '.personal { color: red; }\n' > "$XDG_CONFIG_HOME/gtk-4.0/gtk.css"
mkdir -p "$XDG_CONFIG_HOME/omarchy/hooks/theme-set.d" "$XDG_CONFIG_HOME/omaconf"
printf '%s\n' '#!/bin/bash' 'exec /usr/bin/python "$HOME/.config/omaconf/gtk-unified.py"' > "$XDG_CONFIG_HOME/omarchy/hooks/theme-set.d/zz-unified-icons"
printf '%s\n' 'legacy generator' > "$XDG_CONFIG_HOME/omaconf/gtk-unified.py"
assert_true "GTK integration installs through the user installer" "bash '$PROJECT_DIR/conf/gtk/install.sh'"
assert_file_contains_literal "GTK installer preserves personal Hyprland settings" "$XDG_CONFIG_HOME/hypr/hyprland.lua" 'custom_setting = true'
assert_true "GTK installer retires the competing Python icon hook with a backup" "[[ ! -e '$XDG_CONFIG_HOME/omarchy/hooks/theme-set.d/zz-unified-icons' && ! -e '$XDG_CONFIG_HOME/omaconf/gtk-unified.py' ]] && grep -qx 'legacy generator' '$XDG_CONFIG_HOME/omaconf/migrations/gtk-unified/generator.py'"
assert_true "GTK installer provisions the canonical terminal icon assets" "cmp '$PROJECT_DIR/conf/gtk/data/nerd-icons/aliases.tsv' '$XDG_CONFIG_HOME/omaconf/nerd-icons/aliases.tsv'"
assert_true "GTK integration is idempotent" "before=\$(sha256sum '$XDG_CONFIG_HOME/hypr/hyprland.lua' '$XDG_CONFIG_HOME/hypr/omaconf-gtk.lua'); bash '$PROJECT_DIR/conf/gtk/install.sh'; [[ \"\$before\" == \"\$(sha256sum '$XDG_CONFIG_HOME/hypr/hyprland.lua' '$XDG_CONFIG_HOME/hypr/omaconf-gtk.lua')\" ]]"
printf 'mode = "dark"\nbackground = "#101010"\nforeground = "#eeeeee"\naccent = "#abcdef"\nselection = "#303030"\nmuted = "#777777"\nred = "#ff0000"\ngreen = "#00ff00"\nblue = "#0000ff"\nyellow = "#ffff00"\ncyan = "#00ffff"\nmagenta = "#ff00ff"\n' > "$SANDBOX/palette.toml"
export OMACONF_THEME_NAME=test OMACONF_THEME_COLORS="$SANDBOX/palette.toml"
mkdir -p "$XDG_CONFIG_HOME/zed/themes"
printf '%s\n' '{"author":"omaconf","themes":[{"name":"Omaconf retired"}]}' > "$XDG_CONFIG_HOME/zed/themes/omaconf-retired.json"
printf '%s\n' '{"author":"personal","themes":[{"name":"Personal"}]}' > "$XDG_CONFIG_HOME/zed/themes/omaconf-personal.json"
assert_true "GTK flat palette generation succeeds" "bash '$PROJECT_DIR/hooks/theme-set.d/gtk-theme'"
assert_file_contains_literal "GTK preserves personal CSS" "$XDG_CONFIG_HOME/gtk-4.0/gtk.css" '.personal { color: red; }'
assert_true "GTK flat palette generation is idempotent" "before=\$(sha256sum '$XDG_CONFIG_HOME/gtk-4.0/gtk.css' '$XDG_CONFIG_HOME/gtk-4.0/omaconf.css'); bash '$PROJECT_DIR/hooks/theme-set.d/gtk-theme'; [[ \"\$before\" == \"\$(sha256sum '$XDG_CONFIG_HOME/gtk-4.0/gtk.css' '$XDG_CONFIG_HOME/gtk-4.0/omaconf.css')\" ]]"
assert_file_contains_literal "GTK headerbars use the palette background" "$XDG_CONFIG_HOME/gtk-4.0/omaconf.css" '--headerbar-bg-color: #101010;'
assert_file_contains_literal "GTK cards use the palette background" "$XDG_CONFIG_HOME/gtk-4.0/omaconf.css" '--card-bg-color: #101010;'
assert_true "Zed palette generates and selects a native theme" "bash '$PROJECT_DIR/conf/zed/theme.sh'"
assert_false "Zed removes retired generated themes" "test -e '$XDG_CONFIG_HOME/zed/themes/omaconf-retired.json'"
assert_true "Zed preserves personal themes" "test -e '$XDG_CONFIG_HOME/zed/themes/omaconf-personal.json'"
assert_true "Zed theme uses the palette and preserves editor preferences" "jq -e '.themes[0].appearance == \"dark\" and .themes[0].style[\"editor.background\"] == \"#101010\" and .themes[0].style.syntax.keyword.color == \"#ff00ff\"' '$XDG_CONFIG_HOME/zed/themes/omaconf.json' && jq -e '.disable_ai == true and (.theme | startswith(\"Omaconf \"))' '$XDG_CONFIG_HOME/zed/settings.json'"
assert_true "Zed theme synchronization is idempotent" "before=\$(sha256sum '$XDG_CONFIG_HOME/zed/themes/omaconf.json' '$XDG_CONFIG_HOME/zed/settings.json'); bash '$PROJECT_DIR/conf/zed/theme.sh'; [[ \"\$before\" == \"\$(sha256sum '$XDG_CONFIG_HOME/zed/themes/omaconf.json' '$XDG_CONFIG_HOME/zed/settings.json')\" ]]"
sed -i 's/"dark"/"light"/; s/#101010/#f0f0f0/' "$OMACONF_THEME_COLORS"
assert_true "Zed follows a subsequent light palette" "bash '$PROJECT_DIR/conf/zed/theme.sh' && jq -e '.themes[0].appearance == \"light\" and .themes[0].style[\"editor.background\"] == \"#f0f0f0\"' '$XDG_CONFIG_HOME/zed/themes/omaconf.json'"
sed -i 's/#f0f0f0/invalid/' "$OMACONF_THEME_COLORS"
assert_false "invalid GTK palette fails before replacing CSS" "bash '$PROJECT_DIR/hooks/theme-set.d/gtk-theme'"
assert_file_contains_literal "invalid GTK palette preserves previous CSS" "$XDG_CONFIG_HOME/gtk-4.0/omaconf.css" '--window-bg-color: #101010;'
assert_false "invalid Zed palette fails before replacing the theme" "bash '$PROJECT_DIR/conf/zed/theme.sh'"
assert_true "invalid palette preserves the previous Zed theme" "jq -e '.themes[0].style[\"editor.background\"] == \"#f0f0f0\"' '$XDG_CONFIG_HOME/zed/themes/omaconf.json'"
unset OMACONF_THEME_NAME OMACONF_THEME_COLORS
printf '[Desktop Entry]\nType=Application\nName=Sample\nExec=/usr/bin/sample --original %%U\n' > "$SANDBOX/sample.desktop"
assert_true "Electron integration preserves packaged launcher arguments" "install_user_electron_launcher '$SANDBOX/sample.desktop' '$SANDBOX/result.desktop'"
assert_file_contains_literal "Electron preserves native backend selection and portals" "$SANDBOX/result.desktop" 'Exec=env GTK_USE_PORTAL=1 /usr/bin/sample --original %U'
assert_file_not_contains "Electron does not force an invalid Ozone backend" "$SANDBOX/result.desktop" 'ozone-platform=auto'
if command -v desktop-file-validate >/dev/null; then
    assert_true "generated launcher is a valid desktop entry" "desktop-file-validate '$SANDBOX/result.desktop'"
fi
test_summary
