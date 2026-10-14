#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_DIR/scripts/lib/theme-preview.sh"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
i18n_init
[[ "${OS_APPLY_PIPELINE:-0}" == 1 ]] || err "preview.pipeline"
(($#)) || err "preview.usage" "${0##*/}"
themes=("$@")
for dependency in awk hyprctl identify jq magick grim setsid dbus-run-session zed nautilus gsettings pgrep omarchy; do
    command -v "$dependency" >/dev/null || err "preview.dependency" "$dependency"
done
for theme in "${themes[@]}"; do
    [[ "$theme" =~ ^[a-z0-9-]+$ && -r "/usr/share/omarchy/themes/$theme/colors.toml" ]] || {
        err "preview.theme_invalid" "$theme"
    }
done

ZED_PID=""
NAUTILUS_PID=""
ZED_LIVE_VERIFIED=0
CAPTURE_WORKSPACE=""
ORIGINAL_WORKSPACE="$(hyprctl -j activeworkspace | jq -er '.id')"
ORIGINAL_THEME="$(cat "$HOME/.local/state/omarchy/current/theme.name")"
ORIGINAL_BACKGROUND="$(readlink -f "$HOME/.local/state/omarchy/current/background")"
CAPTURE_MONITOR="$(hyprctl -j monitors | jq -er '.[] | select(.focused) | .name')"
THEME_CHANGED=0
ORIGINAL_DND=$(omarchy shell notifications dndState)
[[ "$ORIGINAL_DND" == on || "$ORIGINAL_DND" == off ]] || err "preview.capture_invalid"
ARTIFACTS_DIR="$(mktemp -d "${TMPDIR:-/tmp}/os-preview.XXXXXX")"

stop_capture_process() {
    local pid="$1" status
    if kill -0 "$pid" 2>/dev/null; then kill -- "-$pid" || return 1; fi
    if wait "$pid"; then return 0; else status=$?; fi
    [[ "$status" == 143 ]] || { warn "preview.process_failed" "$status"; return 1; }
}
focus_workspace() {
    hyprctl dispatch "hl.dsp.focus({ workspace = \"$1\" })" >/dev/null
}
cleanup() {
    local status=$?
    trap - EXIT INT TERM
    if [[ -n "$ZED_PID" ]]; then stop_capture_process "$ZED_PID" || status=1; fi
    if [[ -n "$NAUTILUS_PID" ]]; then stop_capture_process "$NAUTILUS_PID" || status=1; fi
    if ((THEME_CHANGED)); then
        omarchy theme set "$ORIGINAL_THEME" || status=1
        if [[ -f "$ORIGINAL_BACKGROUND" ]]; then omarchy theme bg set "$ORIGINAL_BACKGROUND" || status=1; fi
    fi
    if [[ -n "$CAPTURE_WORKSPACE" ]]; then focus_workspace "$ORIGINAL_WORKSPACE" || status=1; fi
    omarchy shell notifications setDnd "$ORIGINAL_DND" || status=1
    rm -rf -- "$ARTIFACTS_DIR" || status=1
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for candidate in {90..999}; do
    if ! hyprctl -j workspaces | jq -e --argjson id "$candidate" '.[] | select(.id == $id)' >/dev/null; then
        CAPTURE_WORKSPACE="$candidate"
        break
    fi
done
[[ -n "$CAPTURE_WORKSPACE" ]] || err "preview.workspace_missing"
omarchy shell notifications setDnd on
mkdir -p "$ARTIFACTS_DIR/dbus-services"
cat > "$ARTIFACTS_DIR/session.conf" <<EOF_BUS
<busconfig>
  <type>session</type>
  <listen>unix:tmpdir=/tmp</listen>
  <auth>EXTERNAL</auth>
  <servicedir>$ARTIFACTS_DIR/dbus-services</servicedir>
  <policy context="default">
    <allow own="*"/>
    <allow send_destination="*"/>
    <allow receive_sender="*"/>
  </policy>
</busconfig>
EOF_BUS
mkdir -p "$ARTIFACTS_DIR/Files/Documents" "$ARTIFACTS_DIR/Files/Pictures" "$ARTIFACTS_DIR/Files/Projects"
cat > "$ARTIFACTS_DIR/Files/Projects/sample.rs" <<'RUST'
fn sorted_unique(mut items: Vec<i32>) -> Vec<i32> {
    items.sort_unstable();
    items.dedup();
    items
}

fn main() {
    let values = vec![8, 3, 5, 3, 1];
    let result = sorted_unique(values);
    println!("Sorted values: {result:?}");
}
RUST

capture_app() {
    local app="$1" client="" address monitor width height x y group pids side geometry
    if [[ "$app" == zed ]]; then group="$ZED_PID"; else group="$NAUTILUS_PID"; fi
    for _ in {1..300}; do
        if pids=$(pgrep -g "$group"); then
            pids=$(jq -cs '.' <<< "$pids")
            client="$(hyprctl -j clients | jq -c --arg app "$app" --argjson pids "$pids" \
                '.[] | select((.class | ascii_downcase) == (if $app == "zed" then "dev.zed.zed" else ($app | ascii_downcase) end)) | .pid as $pid | select($pids | index($pid))')"
        else
            warn "preview.window_missing" "$app"
            return 1
        fi
        [[ -n "$client" ]] && break
        sleep 0.1
    done
    [[ -n "$client" ]] || { warn "preview.window_missing" "$app"; return 1; }
    address=$(jq -er '.address' <<< "$client")
    hyprctl dispatch "hl.dsp.window.move({ window = \"address:$address\", workspace = \"$CAPTURE_WORKSPACE\", follow = true })" >/dev/null
    monitor=$(hyprctl -j monitors | jq -c --arg name "$CAPTURE_MONITOR" '.[] | select(.name == $name)')
    if [[ "$app" == zed ]]; then side=left; else side=right; fi
    geometry=$(theme_preview_window_geometry "$monitor" "$side")
    IFS=$'\t' read -r x y width height <<< "$geometry"
    hyprctl dispatch "hl.dsp.window.float({ window = \"address:$address\", action = \"enable\" })" >/dev/null
    hyprctl dispatch "hl.dsp.window.resize({ window = \"address:$address\", x = $width, y = $height })" >/dev/null
    hyprctl dispatch "hl.dsp.window.move({ window = \"address:$address\", x = $x, y = $y })" >/dev/null
}

verify_zed_live_theme() {
    local source="$1" config="$2" expected image pixel monitor x y
    expected=$(awk -F '"' '/^background[[:space:]]*=/ { print tolower(substr($2, 2)); exit }' "$source")
    [[ "$expected" =~ ^[0-9a-f]{6}$ ]] || err "preview.capture_invalid"
    XDG_CONFIG_HOME="$config" OS_ZED_CONFIG_DIR="$config/zed-data/config" OS_THEME_COLORS="$source" bash "$PROJECT_DIR/conf/zed/theme.sh"
    monitor=$(hyprctl -j monitors | jq -c --arg name "$CAPTURE_MONITOR" '.[] | select(.name == $name)')
    x=$(jq -r '.width * 0.4 | floor' <<< "$monitor")
    y=$(jq -r '.height * 0.9 | floor' <<< "$monitor")
    image="$ARTIFACTS_DIR/zed-live.png"
    for _ in {1..25}; do
        kill -0 "$ZED_PID" || err "preview.capture_invalid"
        grim -o "$CAPTURE_MONITOR" "$image"
        pixel=$(theme_preview_pixel_rgb "$image" "$x" "$y")
        [[ "$pixel" != "$expected" ]] || return 0
        sleep 0.2
    done
    cp "$image" "${TMPDIR:-/tmp}/os-zed-live-failure.png"
    cp "$config/zed-data/config/settings.json" "${TMPDIR:-/tmp}/os-zed-live-failure-settings.json"
    err "preview.zed_live_failed" "$expected" "$pixel"
}

config="$ARTIFACTS_DIR/config"
mkdir -p "$config/data"
ln -s "${XDG_DATA_HOME:-$HOME/.local/share}/icons" "$config/data/icons"
ln -s "${XDG_DATA_HOME:-$HOME/.local/share}/themes" "$config/data/themes"
for theme in "${themes[@]}"; do
    log "preview.started" "$theme"
    THEME_CHANGED=1
    omarchy theme set "$theme"
    sleep 4
    palette="$HOME/.local/state/omarchy/current/theme/colors.toml"
    XDG_CONFIG_HOME="$config" XDG_DATA_HOME="$config/data" XDG_STATE_HOME="$config/state" XDG_BIN_HOME="$config/bin" \
        OS_ZED_CONFIG_DIR="$config/zed-data/config" GSETTINGS_BACKEND=keyfile bash "$PROJECT_DIR/conf/zed/install.sh"
    XDG_CONFIG_HOME="$config" GSETTINGS_BACKEND=keyfile bash "$PROJECT_DIR/conf/nautilus/install.sh"
    capture_settings=$(jq '.session.trust_all_worktrees = true | .languages.Rust.enable_language_server = false | .auto_install_extensions = {"html": false, "rust": false}' "$config/zed-data/config/settings.json")
    install_user_content "$config/zed-data/config/settings.json" 644 preserve-inode <<< "$capture_settings"
    XDG_CONFIG_HOME="$config" OS_THEME_COLORS="$palette" bash "$PROJECT_DIR/hooks/theme-set.d/gtk-theme"
    mode=$(awk -F '"' '/^mode[[:space:]]*=/ { print $2; exit }' "$palette")
    gtk_theme=$(awk -F '=' '/^gtk-theme-name=/ { print $2; exit }' "$config/gtk-3.0/settings.ini")
    icons=OS-Qogir
    printf '[Settings]\ngtk-theme-name=%s\ngtk-icon-theme-name=%s\ngtk-cursor-theme-name=capitaine-cursors\n' "$gtk_theme" "$icons" > "$config/gtk-3.0/settings.ini"
    for setting in "icon-theme:$icons" "gtk-theme:$gtk_theme" "color-scheme:prefer-${mode:-dark}"; do
        XDG_CONFIG_HOME="$config" GSETTINGS_BACKEND=keyfile gsettings set org.gnome.desktop.interface "${setting%%:*}" "${setting#*:}"
    done
    focus_workspace "$CAPTURE_WORKSPACE"
    if [[ -z "$ZED_PID" ]]; then
        setsid env XDG_CONFIG_HOME="$config" XDG_DATA_HOME="$config/data" XDG_CACHE_HOME="$config/cache" \
        XDG_DATA_DIRS="${XDG_DATA_HOME:-$HOME/.local/share}:/usr/local/share:/usr/share" \
        GIO_USE_VFS=local GSETTINGS_BACKEND=keyfile GTK_A11Y=none GTK_USE_PORTAL=0 GTK_THEME="$gtk_theme" \
        XDG_STATE_HOME="$config/state" OS_I18N_BOOT="$PROJECT_DIR/scripts/lib/i18n-boot.sh" \
        dbus-run-session --config-file "$ARTIFACTS_DIR/session.conf" -- zed --foreground --new --user-data-dir "$config/zed-data" "$ARTIFACTS_DIR/Files/Projects" "$ARTIFACTS_DIR/Files/Projects/sample.rs" &
        ZED_PID=$!
    fi
    setsid env XDG_CONFIG_HOME="$config" XDG_DATA_HOME="$config/data" XDG_CACHE_HOME="$config/cache" \
        XDG_DATA_DIRS="${XDG_DATA_HOME:-$HOME/.local/share}:/usr/local/share:/usr/share" \
        GIO_USE_VFS=local GSETTINGS_BACKEND=keyfile GTK_A11Y=none GTK_USE_PORTAL=0 GTK_THEME="$gtk_theme" \
        dbus-run-session --config-file "$ARTIFACTS_DIR/session.conf" -- nautilus --new-window "$ARTIFACTS_DIR/Files" &
    NAUTILUS_PID=$!
    sleep 2
    capture_app zed
    capture_app org.gnome.Nautilus
    sleep 1
    capture_pids=$(pgrep -g "$ZED_PID"; pgrep -g "$NAUTILUS_PID")
    capture_pids=$(jq -cs '.' <<< "$capture_pids")
    hyprctl -j clients | jq -e --argjson workspace "$CAPTURE_WORKSPACE" --argjson pids "$capture_pids" \
        '[.[] | select(.workspace.id == $workspace)] | length == 2 and all(.[]; .pid as $pid | $pids | index($pid) != null)' >/dev/null || err "preview.capture_invalid"
    if ((ZED_LIVE_VERIFIED == 0 && ${#themes[@]} > 1)); then
        verify_zed_live_theme "$palette" "$config"
        verify_zed_live_theme "/usr/share/omarchy/themes/${themes[1]}/colors.toml" "$config"
        verify_zed_live_theme "$palette" "$config"
        ZED_LIVE_VERIFIED=1
        log "preview.zed_live_verified"
    fi
    verify_zed_live_theme "$palette" "$config"
    grim -o "$CAPTURE_MONITOR" "$ARTIFACTS_DIR/desktop.png"
    monitor_geometry=$(hyprctl -j monitors | jq -er --arg name "$CAPTURE_MONITOR" '.[] | select(.name == $name) | "\(.width)x\(.height)"')
    [[ $(identify -format '%wx%h' "$ARTIFACTS_DIR/desktop.png") == "$monitor_geometry" ]] || err "preview.capture_invalid"
    stop_capture_process "$NAUTILUS_PID"
    NAUTILUS_PID=""
    output_dir="$SCRIPT_DIR/$theme"
    mkdir -p "$output_dir"
    magick "$ARTIFACTS_DIR/desktop.png" -depth "$THEME_PREVIEW_DEPTH" -density "$THEME_PREVIEW_DENSITY" "PNG32:$output_dir/preview.png"
done
stop_capture_process "$ZED_PID"
ZED_PID=""
for theme in "${themes[@]}"; do theme_preview_normalize_file "$SCRIPT_DIR/$theme/preview.png"; done
log "preview.done" "${#themes[@]}"
