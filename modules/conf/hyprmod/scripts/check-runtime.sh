#!/usr/bin/env bash

check_hyprmod_runtime() {
    set -euo pipefail
    local package minimum installed
    while IFS=$'\t' read -r package minimum; do
        installed=$(pacman -Q "$package") || return 1
        [[ $(vercmp "${installed#* }" "$minimum") -ge 0 ]] || return 1
    done < "$1"
    "$2/bin/hyprmod" --help >/dev/null
}

check_hyprmod_runtime "$@"
