#!/usr/bin/env bash

test_wallpapers() {
    set -euo pipefail
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
    source "$SCRIPT_DIR/test_lib.sh"
    WORK_DIR=$(mktemp -d)
    trap 'rm -rf -- "$WORK_DIR"' EXIT
    local hook="$PROJECT_DIR/hooks/theme-set.d/wallpaper" logo="$PROJECT_DIR/data/component/wallpaper/krepo.png"
    local output="$WORK_DIR/home/.config/os/backgrounds/fixture" current="$WORK_DIR/home/.local/state/omarchy/current"
    mkdir -p "$current/theme/backgrounds" "$WORK_DIR/data/os/desktop/wallpapers" "$WORK_DIR/bin" "$WORK_DIR/home/.config/omarchy/themes/fixture"
    printf 'fixture\n' > "$current/theme.name"
    printf 'background = "#112233"\nforeground = "#ffffff"\naccent = "#aabbcc"\n' > "$current/theme/colors.toml"
    cp "$logo" "$WORK_DIR/data/os/desktop/wallpapers/krepo.png"
    cp "$PROJECT_DIR/data/component/wallpaper/policy.json" "$WORK_DIR/data/os/desktop/wallpapers/policy.json"
    cp "$logo" "$current/theme/backgrounds/stock.png"
    printf '[{"width":1600,"height":900},{"width":1920,"height":1080}]' > "$WORK_DIR/monitors.json"
    cat > "$WORK_DIR/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cat "$OS_TEST_MONITORS"
SH
    chmod 755 "$WORK_DIR/bin/hyprctl"
    mkdir -p "$WORK_DIR/data/os/desktop/runtime"
    cp -r "$PROJECT_DIR/src" "$PROJECT_DIR/data" "$WORK_DIR/data/os/desktop/runtime/"
    run_wallpaper() {
        env -i PATH="$WORK_DIR/bin:/usr/bin:/bin" HOME="$WORK_DIR/home" XDG_DATA_HOME="$WORK_DIR/data" OS_TEST_MONITORS="$WORK_DIR/monitors.json" bash "$hook" fixture
    }
    assert_true "wallpaper generates one palette based logo design" "run_wallpaper && [[ \$(find '$output' -maxdepth 1 -name '*.png' | wc -l) == 1 ]]"
    assert_true "wallpaper uses the full monitor size" "[[ \$(magick identify -format '%wx%h' '$output/krepo.png') == 1920x1080 ]]"
    assert_true "wallpaper background follows the theme" "[[ \$(magick '$output/krepo.png' -depth 8 -format '%[hex:p{0,0}]' info:) == 112233 ]]"
    assert_true "logo follows the exact theme accent" "magick '$output/krepo.png' -depth 8 -unique-colors txt: | grep -qi '#AABBCC'"
    assert_true "active background points to the branded wallpaper" "[[ \$(readlink '$current/background') == '$output/krepo.png' ]]"
    assert_true "stock backgrounds leave the chooser and are preserved in the archive" "[[ -z \$(find '$current/theme/backgrounds' -mindepth 1 -print -quit) && \$(find '$WORK_DIR/data/os/retired-backgrounds' -name stock.png | wc -l) == 1 ]]"
    local before
    before=$(cat "$output/.os-wallpaper.sha256")
    assert_true "unchanged content preserves the wallpaper cache" "run_wallpaper && [[ \$(cat '$output/.os-wallpaper.sha256') == '$before' ]]"
    touch "$WORK_DIR/data/os/desktop/wallpapers/krepo.png"
    assert_true "timestamps alone do not invalidate identical images" "run_wallpaper && [[ \$(cat '$output/.os-wallpaper.sha256') == '$before' ]]"
    cp "$output/krepo.png" "$output/krepo-corner.png"
    mkdir -p "$WORK_DIR/home/.config/omarchy/backgrounds/fixture"
    cp "$logo" "$WORK_DIR/home/.config/omarchy/backgrounds/fixture/personal.png"
    assert_true "old variants and personal backgrounds are archived outside the chooser" "run_wallpaper && [[ ! -e '$output/krepo-corner.png' && ! -e '$WORK_DIR/home/.config/omarchy/backgrounds/fixture/personal.png' ]] && find '$WORK_DIR/data/os/retired-backgrounds' -name personal.png | grep -q ."
    assert_true "native chooser contains exactly one palette wallpaper" "[[ \$(find -L '$WORK_DIR/home/.config/omarchy/backgrounds/fixture' -maxdepth 1 -type f | wc -l) == 1 ]]"
    mv "$output/krepo.png" "$WORK_DIR/missing.png"
    assert_true "missing generated wallpapers are restored" "run_wallpaper && cmp '$output/krepo.png' '$WORK_DIR/missing.png'"
    printf '[{"width":2560,"height":1440}]' > "$WORK_DIR/monitors.json"
    assert_true "monitor changes invalidate the cached wallpaper" "run_wallpaper && [[ \$(magick identify -format '%wx%h' '$output/krepo.png') == 2560x1440 ]]"
    printf '[{"width":1920,"height":1080,"transform":1}]' > "$WORK_DIR/monitors.json"
    assert_true "rotated monitors use the effective physical geometry" "run_wallpaper && [[ \$(magick identify -format '%wx%h' '$output/krepo.png') == 1080x1920 ]]"
    printf '[]' > "$WORK_DIR/monitors.json"
    assert_false "malformed monitor data fails instead of hiding geometry errors" "run_wallpaper"
    printf '[{"width":1920,"height":1080}]' > "$WORK_DIR/monitors.json"
    printf 'accent = "invalid"\n' >> "$current/theme/colors.toml"
    assert_false "invalid palette colors are rejected" "run_wallpaper"
    test_summary
}

test_wallpapers "$@"
