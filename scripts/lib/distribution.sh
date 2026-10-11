#!/usr/bin/env bash

kos_version() {
    local version
    version=$(cat "$1/conf/kos/data/version") || return 1
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
    printf '%s\n' "$version"
}

kos_package_stage() {
    local project="$1" root="$2" version="$3" theme app
    [[ "$version" == "$(kos_version "$project")" && ! -e "$root" ]] || return 1
    install -d -m 755 "$root"
    cp -a "$project/conf/kos/data/rootfs/." "$root/" || return 1
    install -d -m 755 "$root/usr/share/kos/provision"
    tar -C "$project" --exclude=.git --exclude=dist --exclude='*.log' \
        --exclude=conf/kos/data/rootfs --exclude=conf/kos/data/packages --exclude=conf/kos/data/migration-packages.list --exclude=conf/kos/data/legacy-automation \
        -cf - scripts hooks conf theme-previews Makefile setup.sh | \
        tar -C "$root/usr/share/kos/provision" -xf - || return 1
    install -d -m 755 "$root/usr/share/kos/lib/messages"
    cp "$project/scripts/lib/i18n.sh" "$root/usr/share/kos/lib/i18n.sh" || return 1
    cp "$project/scripts/lib/release-manifest.sh" "$root/usr/share/kos/lib/release-manifest.sh" || return 1
    cp "$project/scripts/lib/release-query.sh" "$root/usr/share/kos/lib/release-query.sh" || return 1
    cp "$project/scripts/lib/messages/"*.msg "$root/usr/share/kos/lib/messages/" || return 1
    theme=$(cat "$project/conf/kos/data/default-theme") || return 1
    [[ "$theme" =~ ^[a-zA-Z0-9_-]+$ && -d "$root/usr/share/kos/themes/$theme" ]] || return 1
    install -d -m 755 "$root/etc/skel/.config" "$root/etc/skel/.local/state/kos/current"
    for app in hypr kos kitty foot ghostty alacritty fcitx5 wireplumber starship.toml; do
        cp -a "$root/usr/share/kos/config/$app" "$root/etc/skel/.config/" || return 1
    done
    cp -a "$root/usr/share/kos/themes/$theme" "$root/etc/skel/.local/state/kos/current/next-theme" || return 1
    env HOME="$root/etc/skel" KOS_PATH="$root/usr/share/kos" PATH="$root/usr/bin:$PATH" \
        bash "$root/usr/bin/kos-theme-set-templates" || return 1
    mv "$root/etc/skel/.local/state/kos/current/next-theme" "$root/etc/skel/.local/state/kos/current/theme" || return 1
    printf '%s\n' "$theme" > "$root/etc/skel/.local/state/kos/current/theme.name" || return 1
    printf 'source /usr/share/kos/default/bash/rc\n' > "$root/etc/skel/.bashrc" || return 1
    install -Dm644 "$project/conf/gtk/data/tiling.lua" "$root/etc/skel/.config/hypr/kos-gtk.lua" || return 1
    printf '\nrequire("kos-gtk")\n' >> "$root/etc/skel/.config/hypr/hyprland.lua" || return 1
    install -d -m 755 "$root/etc/skel/.config/kos/hooks/theme-set.d"
    cp "$project/hooks/theme-set.d/"* "$root/etc/skel/.config/kos/hooks/theme-set.d/" || return 1
    cp -a "$root/usr/share/kos/lib" "$root/etc/skel/.config/kos/hooks/i18n" || return 1
    install -d -m 755 "$root/etc/skel/.config/kos/branding"
    cp "$root/usr/share/kos/icon.txt" "$root/etc/skel/.config/kos/branding/about.txt" || return 1
    cp "$root/usr/share/kos/logo.txt" "$root/etc/skel/.config/kos/branding/screensaver.txt" || return 1
    printf '%s\n' "$version" > "$root/usr/share/kos/version" || return 1
    find "$root" -type d -exec chmod 755 {} + || return 1
    find "$root" -type f -perm /111 -exec chmod 755 {} + || return 1
    find "$root" -type f ! -perm /111 -exec chmod 644 {} + || return 1
}

kos_package_build() {
    local project="$1" output="$2" work version package dependency timestamp file
    version=$(kos_version "$project") || return 1
    timestamp="${SOURCE_DATE_EPOCH:-$(git -C "$project" log -1 --format=%ct)}"
    [[ "$timestamp" =~ ^[0-9]+$ ]] || return 1
    install -d -m 755 "$output"
    work=$(mktemp -d "$output/.package.XXXXXX") || return 1
    if ! kos_package_stage "$project" "$work/root" "$version"; then
        rm -rf "$work"
        return 1
    fi
    {
        printf 'pkgname = kos\npkgbase = kos\npkgver = %s-1\npkgdesc = kos desktop and provisioning runtime\nurl = https://github.com/kairosci/kos\nbuilddate = %s\npackager = kos\nsize = %s\narch = x86_64\nlicense = MIT\nlicense = GPL-3.0-only\n' \
            "$version" "$timestamp" "$(du -sb "$work/root" | cut -f1)"
        while IFS= read -r dependency; do
            [[ -z "$dependency" ]] || printf 'depend = %s\n' "$dependency"
        done < "$project/conf/kos/data/runtime-packages.list"
        while IFS= read -r dependency; do
            [[ -z "$dependency" ]] || printf 'provides = %s\n' "$dependency"
        done < "$project/conf/kos/data/runtime-provides.list"
        while IFS= read -r -d '' file; do
            printf 'backup = %s\n' "${file#"$work/root/"}"
        done < <(find "$work/root/etc" -type f -print0 | LC_ALL=C sort -z)
        while IFS= read -r package; do
            [[ -z "$package" ]] || printf 'conflict = %s\nreplaces = %s\n' "$package" "$package"
        done < "$project/conf/kos/data/migration-packages.list"
    } > "$work/root/.PKGINFO" || { rm -rf "$work"; return 1; }
    chmod 644 "$work/root/.PKGINFO" || { rm -rf "$work"; return 1; }
    find "$work/root" -exec touch -h -d "@$timestamp" {} + || { rm -rf "$work"; return 1; }
    if ! bsdtar --format=mtree --options='!all,use-set,type,uid,gid,mode,time,size,sha256,link' \
        --uid 0 --gid 0 -C "$work/root" -cf - . | gzip -cn > "$work/root.MTREE"; then
        rm -rf "$work"
        return 1
    fi
    install -m 644 "$work/root.MTREE" "$work/root/.MTREE" || { rm -rf "$work"; return 1; }
    package="$output/kos-$version-1-x86_64.pkg.tar.zst"
    local -a root_entries=()
    mapfile -t root_entries < <(find "$work/root" -mindepth 1 -maxdepth 1 ! -name '.PKGINFO' ! -name '.MTREE' -printf '%P\n' | LC_ALL=C sort)
    if ! bsdtar --format=gnutar --uid 0 --gid 0 --numeric-owner --mtime="@$timestamp" \
        -C "$work/root" -cf - .PKGINFO .MTREE "${root_entries[@]}" | zstd -T0 -19 -o "$work/package.pkg.tar.zst"; then
        rm -rf "$work"
        return 1
    fi
    chmod 644 "$work/package.pkg.tar.zst" || { rm -rf "$work"; return 1; }
    mv -f "$work/package.pkg.tar.zst" "$package" || { rm -rf "$work"; return 1; }
    rm -rf "$work"
    printf '%s\n' "$package"
}
