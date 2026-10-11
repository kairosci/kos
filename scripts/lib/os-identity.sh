#!/usr/bin/env bash

kos_identity_valid() {
    local root="${1:-}"
    [[ -r "$root/usr/lib/os-release" && -r "$root/etc/os-release" ]] || return 1
    grep -qE '^ID=(arch|"arch")$' "$root/usr/lib/os-release" || return 1
    grep -qx 'ID=kos' "$root/etc/os-release" || return 1
    grep -qx 'ID_LIKE=arch' "$root/etc/os-release" || return 1
    grep -qx 'NAME="kos"' "$root/etc/os-release" || return 1
}

kos_identity_apply() {
    local root="${1:-}" version="${2:-}" destination backup staged
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    [[ -r "$root/usr/lib/os-release" ]] || return 1
    grep -qE '^ID=(arch|"arch")$' "$root/usr/lib/os-release" || return 1
    destination="$root/etc/os-release"
    backup="$root/var/lib/kos/os-identity"
    [[ ! -d "$destination" ]] || return 1
    if [[ -e "$destination" && ! -e "$backup/os-release" ]]; then
        install -d -m 700 "$backup" || return 1
        cp -L --preserve=mode,timestamps "$destination" "$backup/os-release" || return 1
        chmod 600 "$backup/os-release" || return 1
    fi
    staged=$(mktemp "$root/etc/.os-release.XXXXXX") || return 1
    if ! printf 'NAME="kos"\nPRETTY_NAME="kos %s"\nID=kos\nID_LIKE=arch\nVERSION_ID="%s"\nBUILD_ID=rolling\nHOME_URL="https://github.com/kairosci/kos"\nSUPPORT_URL="https://github.com/kairosci/kos/issues"\nLOGO=kos\n' "$version" "$version" > "$staged"; then
        rm -f "$staged"
        return 1
    fi
    chmod 644 "$staged" || { rm -f "$staged"; return 1; }
    if [[ -f "$destination" && ! -L "$destination" ]] && cmp -s "$staged" "$destination"; then
        rm -f "$staged"
        return 0
    fi
    mv -fT "$staged" "$destination" || { rm -f "$staged"; return 1; }
}
