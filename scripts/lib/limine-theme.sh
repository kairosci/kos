#!/usr/bin/env bash

set -euo pipefail

theme_apply() {
    local esp_path=/boot config wallpaper temp hash
    [[ $EUID -eq 0 ]] || { printf '%s\n' 'Limine theme requires root.' >&2; return 1; }
    if [[ -f /etc/default/limine ]]; then
        source /etc/default/limine
        esp_path=${ESP_PATH:-/boot}
    fi
    [[ $esp_path == /* && -d $esp_path && -f $esp_path/limine.conf ]] || {
        printf 'Limine config was not found at %s/limine.conf.\n' "$esp_path" >&2
        return 1
    }
    wallpaper=/usr/share/os/limine/wallpaper.png
    [[ -s $wallpaper ]] || { printf '%s\n' 'Limine wallpaper asset is missing.' >&2; return 1; }
    config=$esp_path/limine.conf
    hash=$(b2sum "$wallpaper" | awk '{print $1}')
    if [[ ! -e $config.os-backup ]]; then
        cp -- "$config" "$config.os-backup"
    fi
    install -m 644 -- "$wallpaper" "$esp_path/os-wallpaper.png"
    temp=$(mktemp "$esp_path/.limine-theme.XXXXXX")
    trap 'rm -f -- "$temp"' RETURN
    awk '
        /^# OS_THEME_BEGIN$/ { skip=1; next }
        /^# OS_THEME_END$/ { skip=0; next }
        !skip { print }
    ' "$config" > "$temp"
    {
        printf '%s\n' '# OS_THEME_BEGIN'
        printf '%s\n' 'interface_branding: KMono OS'
        printf '%s\n' 'interface_branding_colour: 35D8E8'
        printf '%s\n' 'interface_help_colour: C6F4F7'
        printf '%s\n' 'interface_help_colour_bright: 35D8E8'
        printf 'wallpaper: boot():/os-wallpaper.png#%s\n' "$hash"
        printf '%s\n' 'wallpaper_style: stretched'
        printf '%s\n' 'backdrop: 07131D'
        printf '%s\n' 'graphics: yes'
        printf '%s\n' 'terse: yes'
        printf '%s\n' 'measured_boot: yes'
        printf '%s\n' 'hash_mismatch_panic: yes'
        printf '%s\n' 'term_background: B00B1620'
        printf '%s\n' 'term_foreground: E8FAFC'
        printf '%s\n' 'term_background_bright: 182C37'
        printf '%s\n' 'term_foreground_bright: 35D8E8'
        printf '%s\n' 'term_margin: 36'
        printf '%s\n' 'term_margin_gradient: 6'
        printf '%s\n' '# OS_THEME_END'
        cat -- "$temp"
    } > "$temp.new"
    cat -- "$temp.new" > "$temp"
    rm -f -- "$temp.new"
    chmod 644 "$temp"
    mv -f -- "$temp" "$config"
    trap - RETURN
    sync -f "$config"
}

theme_apply "$@"
