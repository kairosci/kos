#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
WORK_DIR=$(mktemp -d)
trap 'rm -rf -- "$WORK_DIR"' EXIT
HOOK="$PROJECT_DIR/hooks/theme-set.d/wallpaper"
LOGO="$PROJECT_DIR/modules/conf/desktop/data/wallpapers/krepo.png"
INSTALLER="$PROJECT_DIR/modules/conf/desktop/install.sh"
assert_file_exists "krepo logo source is tracked" "$LOGO"
assert_true "krepo logo is a PNG image" "file '$LOGO' | grep -q PNG"
assert_file_exists "wallpaper hook exists" "$HOOK"
assert_file_executable "wallpaper hook is executable" "$HOOK"
assert_true "wallpaper hook passes syntax check" "bash -n '$HOOK'"
assert_file_contains "wallpaper hook uses strict mode" "$HOOK" "set -euo pipefail"
assert_true "wallpaper hook carries no comments" "! grep -q '^\\s*#[^!]' '$HOOK'"
assert_file_contains "wallpaper hook reads the theme palette" "$HOOK" "colors.toml"
assert_file_contains "wallpaper hook composites with ImageMagick" "$HOOK" "magick"
assert_file_contains "wallpaper hook publishes through the native override directory" "$HOOK" ".config/omarchy/backgrounds/"
assert_file_contains "wallpaper hook updates the current background link" "$HOOK" "current/background"
assert_file_contains "desktop installer stages the krepo logo" "$INSTALLER" "wallpapers/krepo.png"
assert_file_contains "desktop installer applies the wallpaper hook" "$INSTALLER" "theme-set.d/wallpaper"
mkdir -p "$WORK_DIR/home/.local/state/omarchy/current" "$WORK_DIR/home/.config/omarchy/themes/fixture" "$WORK_DIR/data/os/desktop/wallpapers" "$WORK_DIR/fakebin"
printf 'fixture\n' > "$WORK_DIR/home/.local/state/omarchy/current/theme.name"
printf 'background = "#112233"\nforeground = "#ffffff"\n' > "$WORK_DIR/home/.config/omarchy/themes/fixture/colors.toml"
cp "$LOGO" "$WORK_DIR/data/os/desktop/wallpapers/krepo.png"
cat > "$WORK_DIR/fakebin/hyprctl" <<'SH'
#!/usr/bin/env bash
printf '[{"width":1600,"height":900},{"width":1920,"height":1080}]'
SH
chmod +x "$WORK_DIR/fakebin/hyprctl"
run_hook() {
    env -i PATH="$WORK_DIR/fakebin:/usr/bin:/bin" HOME="$WORK_DIR/home" XDG_DATA_HOME="$WORK_DIR/data" XDG_STATE_HOME="$WORK_DIR/home/.local/state" bash "$HOOK" fixture
}
assert_true "wallpaper hook generates the themed krepo background" "run_hook"
assert_true "generated wallpaper matches the widest monitor" "identify -format '%wx%h' '$WORK_DIR/home/.config/omarchy/backgrounds/fixture/krepo.png' | grep -qx '1920x1080'"
assert_true "generated wallpaper uses the theme background color" "magick '$WORK_DIR/home/.config/omarchy/backgrounds/fixture/krepo.png' -depth 8 -format '%[hex:p{0,0}]' info: | grep -qi '112233'"
assert_true "current background points at the krepo wallpaper" "[[ \"\$(readlink '$WORK_DIR/home/.local/state/omarchy/current/background')\" == '$WORK_DIR/home/.config/omarchy/backgrounds/fixture/krepo.png' ]]"
SHA_BEFORE=$(sha256sum "$WORK_DIR/home/.config/omarchy/backgrounds/fixture/krepo.png" | cut -d' ' -f1)
assert_true "wallpaper generation is idempotent" "run_hook && [[ \"\$(sha256sum '$WORK_DIR/home/.config/omarchy/backgrounds/fixture/krepo.png' | cut -d' ' -f1)\" == '$SHA_BEFORE' ]]"
sleep 1
touch "$WORK_DIR/data/os/desktop/wallpapers/krepo.png"
assert_true "wallpaper regenerates after the logo changes" "run_hook && [[ \"\$(sha256sum '$WORK_DIR/home/.config/omarchy/backgrounds/fixture/krepo.png' | cut -d' ' -f1)\" != '$SHA_BEFORE' ]]"
assert_true "wallpaper hook fails loudly on an unknown theme" "! env -i PATH='$WORK_DIR/fakebin:/usr/bin:/bin' HOME='$WORK_DIR/home' XDG_DATA_HOME='$WORK_DIR/data' XDG_STATE_HOME='$WORK_DIR/home/.local/state' bash '$HOOK' nonexistent-theme"
test_summary
