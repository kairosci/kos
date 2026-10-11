#!/usr/bin/env bash

package_pins_existing() {
    awk '
        /^[[:space:]]*IgnorePkg[[:space:]]*=/ {
            sub(/^[^=]*=[[:space:]]*/, "")
            sub(/[[:space:]]*#.*/, "")
            for (i = 1; i <= NF; i++)
                if ($i != "brave-origin-bin" && $i != "nautilus" && !seen[$i]++)
                    printf "%s ", $i
        }
    ' "$1"
}

package_pins_retained_updateable() {
    local pins pattern package
    pins=$(pacman-conf IgnorePkg) || return 1
    [[ -z "${pins//[[:space:]]/}" ]] && return 0
    while IFS= read -r pattern; do
        [[ -n "$pattern" ]] || continue
        for package in nautilus brave-origin-bin; do
            # shellcheck disable=SC2053
            [[ "$package" != $pattern ]] || return 1
        done
    done <<< "$pins"
    return 0
}
