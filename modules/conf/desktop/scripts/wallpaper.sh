#!/usr/bin/env bash

wallpaper_palette() {
    awk -F '"' -v key="$1" '$1 ~ "^[[:space:]]*" key "[[:space:]]*=" { value=$2 } END { print value }' "$WALLPAPER_COLORS"
}

render_wallpapers() {
    set -euo pipefail
    local theme="${1:-}" data="${XDG_DATA_HOME:-$HOME/.local/share}" config="${XDG_CONFIG_HOME:-$HOME/.config}"
    local current="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current" policy logo palette_dir
    [[ -n "$theme" ]] || theme=$(cat "$current/theme.name")
    [[ "$theme" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || err "wallpaper.failed" "$theme"
    policy="$data/os/desktop/wallpapers/policy.json"
    logo="$data/os/desktop/wallpapers/krepo.png"
    [[ -r "$logo" && -r "$policy" ]] || err "wallpaper.failed" "$theme"
    WALLPAPER_COLORS=''
    for palette_dir in "${OMARCHY_PATH:-/usr/share/omarchy}/themes/$theme" "$config/omarchy/themes/$theme"; do
        [[ ! -r "$palette_dir/colors.toml" ]] || WALLPAPER_COLORS="$palette_dir/colors.toml"
    done
    if [[ -r "$current/theme.name" && "$(cat "$current/theme.name")" == "$theme" && -r "$current/theme/colors.toml" ]]; then
        WALLPAPER_COLORS="$current/theme/colors.toml"
    fi
    [[ -n "$WALLPAPER_COLORS" ]] || err "wallpaper.failed" "$theme"
    local background foreground accent geometry monitors color
    background=$(wallpaper_palette background)
    foreground=$(wallpaper_palette foreground)
    accent=$(wallpaper_palette accent)
    for color in "$background" "$foreground" "$accent"; do
        [[ "$color" =~ ^#[[:xdigit:]]{6}$ ]] || err "wallpaper.failed" "$theme"
    done
    jq -e '.variants | length > 0 and all(.[]; (.id|test("^krepo(-[a-z]+)?$")) and (.role=="accent" or .role=="foreground") and (.size>0 and .size<=1) and (.opacity>0 and .opacity<=1) and (.gravity=="center" or .gravity=="southeast"))' "$policy" >/dev/null || err "wallpaper.failed" "$theme"
    if monitors=$(hyprctl monitors -j); then
        geometry=$(jq -er 'if type=="array" and length>0 and all(.[]; (.width|type=="number") and (.height|type=="number") and .width>0 and .height>0 and .width==(.width|floor) and .height==(.height|floor)) then map(if ((.transform//0)%2)==1 then {w:.height,h:.width} else {w:.width,h:.height} end) | "\(map(.w)|max)x\(map(.h)|max)" else error("geometry") end' <<< "$monitors") || err "wallpaper.failed" "$theme"
    elif [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        geometry=$(jq -er '.defaultGeometry' "$policy")
        warn "wallpaper.deferred"
    else
        err "wallpaper.failed" "$theme"
    fi
    [[ "$geometry" =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]] || err "wallpaper.failed" "$theme"
    local width="${geometry%x*}" height="${geometry#*x}" digest output id role size opacity gravity side padding cached=1
    digest=$({ sha256sum "$logo" "$policy"; printf '%s\n' "$background" "$foreground" "$accent" "$geometry"; } | sha256sum)
    digest="${digest%% *}"
    output="$config/os/backgrounds/$theme"
    mkdir -p "$output"
    if [[ ! -f "$output/.os-wallpaper.sha256" || "$(cat "$output/.os-wallpaper.sha256")" != "$digest" ]]; then cached=0; fi
    while IFS= read -r id; do
        [[ -f "$output/$id.png" ]] || cached=0
    done < <(jq -r '.variants[].id' "$policy")
    if [[ "$cached" == 0 ]]; then
        WALLPAPER_STAGE=$(mktemp -d "$output/.render.XXXXXX")
        trap 'rm -rf -- "$WALLPAPER_STAGE"' EXIT
        while IFS=$'\t' read -r id role size opacity gravity; do
            color="$accent"
            [[ "$role" != foreground ]] || color="$foreground"
            side=$(awk -v w="$width" -v h="$height" -v size="$size" 'BEGIN { printf "%d", (w<h?w:h)*size }')
            padding=$(( (width < height ? width : height) / 12 ))
            [[ "$gravity" != center ]] || padding=0
            magick -size "$geometry" "canvas:$background" \
                \( "$logo" -fill "$color" -colorize 100 -channel A -evaluate multiply "$opacity" +channel -resize "${side}x${side}" \) \
                -gravity "$gravity" -geometry "+${padding}+${padding}" -composite -strip -depth 8 -density 72 "$WALLPAPER_STAGE/$id.png"
        done < <(jq -r '.variants[] | [.id,.role,.size,.opacity,.gravity] | @tsv' "$policy")
        for id in "$WALLPAPER_STAGE/"*.png; do mv -Tf -- "$id" "$output/${id##*/}"; done
        printf '%s\n' "$digest" > "$WALLPAPER_STAGE/digest"
        mv -Tf -- "$WALLPAPER_STAGE/digest" "$output/.os-wallpaper.sha256"
    fi
    lua -E - "$data/os/desktop/runtime" "$output" "$config/omarchy/backgrounds/$theme" "$data/os/retired-backgrounds/$theme" "$policy" <<'LUA'
package.path = arg[1] .. "/src/?.lua;" .. package.path
require("component.wallpaper.catalog").run(arg[1], arg[2], arg[3], arg[4], arg[5])
LUA
    if [[ -r "$current/theme.name" && "$(cat "$current/theme.name")" == "$theme" ]]; then
        local stock="$current/theme/backgrounds" archive fingerprint
        if [[ -d "$stock" && ! -L "$stock" ]] && [[ -n "$(find "$stock" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
            fingerprint=$(cd "$stock" && find . -type f -exec sha256sum {} + | LC_ALL=C sort | sha256sum)
            archive="$data/os/retired-backgrounds/$theme/${fingerprint%% *}"
            mkdir -p "${archive%/*}"
            [[ ! -L "$archive" ]] || err "wallpaper.failed" "$theme"
            if [[ ! -e "$archive" ]]; then
                mv -T -- "$stock" "$archive"
            elif diff -qr "$stock" "$archive" >/dev/null; then
                WALLPAPER_STOCK_STAGE=$(mktemp -d "$output/.stock.XXXXXX")
                mv -- "$stock" "$WALLPAPER_STOCK_STAGE/backgrounds"
                rm -rf -- "$WALLPAPER_STOCK_STAGE"
            else
                err "wallpaper.failed" "$theme"
            fi
            mkdir -p "$stock"
        elif [[ -L "$stock" ]]; then
            err "wallpaper.failed" "$theme"
        fi
        mkdir -p "$current"
        ln -sfn "$output/krepo.png" "$current/background"
    fi
}
