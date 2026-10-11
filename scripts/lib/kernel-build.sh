#!/usr/bin/env bash

kos_kernel_build() {
    local project="$1" output="$2" work uid user dependency
    local -a dependencies=()
    [[ $EUID == 0 ]] || err release.root
    command -v makepkg >/dev/null || err release.tools makepkg
    uid="${KOS_BUILDER_UID:-$(stat -c %u "$project")}"
    [[ "$uid" =~ ^[0-9]+$ && "$uid" -gt 0 ]] || err release.invalid
    if user=$(getent passwd "$uid"); then
        user="${user%%:*}"
    else
        user=kosbuild
        if ! useradd -m -u "$uid" "$user" 2>/dev/null; then
            printf '%s:x:%s:%s::/home/%s:/bin/bash\n' "$user" "$uid" "$uid" "$user" >> /etc/passwd
            printf '%s:!::0:::::\n' "$user" >> /etc/shadow
            printf '%s:x:%s:\n' "$user" "$uid" >> /etc/group
            printf '%s:!::\n' "$user" >> /etc/gshadow
            install -d -m 700 -o "$uid" -g "$uid" "/home/$user"
        fi
    fi
    [[ $(id -u "$user") == "$uid" ]] || err release.invalid
    install -d -m 755 "$output"
    work=$(mktemp -d "$output/.kernel.XXXXXX") || err release.invalid
    cp -a "$project/conf/kos/data/packages/linux-kos/." "$work/"
    chown -R "$user:$user" "$work"
    install -d -m 700 -o "$user" -g "$user" "$work/gpg"
    sudo -u "$user" env "GNUPGHOME=$work/gpg" gpg --import "$work"/keys/pgp/*.asc
    dependency=$(sudo -u "$user" bash -c 'cd "$1" && makepkg --printsrcinfo' bash "$work")
    mapfile -t dependencies < <(awk '$1 == "makedepends" || $1 == "makedepends_x86_64" { print $3 }' <<< "$dependency")
    pacman -S --needed --noconfirm base-devel sudo "${dependencies[@]}"
    cp /etc/makepkg.conf "$work/makepkg.conf"
    printf '\nMAKEFLAGS="-j2"\nPKGDEST=%q\nSRCDEST=%q\nSRCPKGDEST=%q\nCOMPRESSZST=(zstd -c -T2 -10)\n' "$output" "$work" "$output" >> "$work/makepkg.conf"
    chown "$user:$user" "$work/makepkg.conf"
    sudo -u "$user" env "GNUPGHOME=$work/gpg" bash -c \
        'set -euo pipefail; cd "$1"; makepkg --config "$1/makepkg.conf" --verifysource; makepkg --config "$1/makepkg.conf" --noconfirm; makepkg --config "$1/makepkg.conf" --allsource' bash "$work"
    chmod 644 "$output"/linux-kos-*.pkg.tar.zst "$output"/linux-kos-*.src.tar.*
    rm -rf "$work"
}
