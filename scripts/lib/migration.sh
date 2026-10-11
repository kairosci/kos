#!/usr/bin/env bash

kos_migrate_preflight() {
    local home="$1" desktop="$2" automation="$3" work directory file
    [[ "$desktop" =~ ^[a-z]+$ && "$automation" =~ ^[a-z]+$ && -d "$home" && ! -L "$home" ]] || return 1
    work=$(mktemp -d) || return 1
    install -d -m 700 "$work/home" || return 1
    for directory in ".config/$desktop" ".config/$automation" .config/kos ".local/state/$desktop" ".local/state/$automation" .local/state/kos ".cache/$desktop" ".cache/$automation" .cache/kos .config/hypr .config/gtk-3.0 .config/gtk-4.0 .config/kitty .config/foot .config/ghostty .config/alacritty .config/environment.d .local/share/applications; do
        [[ -e "$home/$directory" || -L "$home/$directory" ]] || continue
        install -d -m 700 "$work/home/$(dirname "$directory")" || return 1
        cp -a "$home/$directory" "$work/home/$directory" || return 1
    done
    for file in .bashrc .bash_profile .profile .config/slack-flags.conf .config/discord-flags.conf; do
        [[ -e "$home/$file" ]] || continue
        install -d -m 700 "$work/home/$(dirname "$file")" || return 1
        cp -a "$home/$file" "$work/home/$file" || return 1
    done
    if ! kos_migrate_home "$work/home" "$work/backup" "$desktop" "$automation"; then
        rm -rf "$work"
        return 1
    fi
    rm -rf "$work"
}

kos_migrate_text() {
    local file="$1" desktop="$2" automation="$3"
    [[ -f "$file" && ! -L "$file" ]] || return 0
    if LC_ALL=C grep -Iq . "$file"; then
        sed -i \
            -e "s/${desktop^^}/KOS/g" -e "s/${desktop^}/Kos/g" -e "s/$desktop/kos/g" \
            -e "s/${automation^^}/KOS/g" -e "s/${automation^}/Kos/g" -e "s/$automation/kos/g" "$file" || return 1
    fi
}

kos_migrate_tree() {
    local source="$1" destination="$2" backup="$3" desktop="$4" automation="$5" mode="${6:-config}" staged file relative target name
    [[ -e "$source" ]] || return 0
    [[ -d "$source" && ! -L "$source" && ! -L "$destination" && ! -e "$backup" ]] || return 1
    install -d -m 700 "$(dirname "$backup")" || return 1
    staged=$(mktemp -d "$(dirname "$backup")/.normalized.XXXXXX") || return 1
    cp -a "$source/." "$staged/" || return 1
    while IFS= read -r -d '' file; do
        if [[ "$mode" == config || "$mode" == .config || "$file" == "$staged/current/"* ]]; then
            kos_migrate_text "$file" "$desktop" "$automation" || return 1
        fi
    done < <(find "$staged" -path '*/.git' -prune -o -type f -print0)
    while IFS= read -r -d '' file; do
        if [[ -L "$file" ]]; then
            target=$(readlink "$file") || return 1
            target="${target//$desktop/kos}"
            target="${target//$automation/kos}"
            ln -sfn "$target" "$file" || return 1
        fi
        name="${file##*/}"
        target="${name//$desktop/kos}"
        target="${target//$automation/kos}"
        target="${target//${desktop^}/Kos}"
        target="${target//${automation^}/Kos}"
        [[ "$target" == "$name" ]] || mv -T "$file" "${file%/*}/$target" || return 1
    done < <(find "$staged" -depth -mindepth 1 -print0)
    while IFS= read -r -d '' file; do
        relative="${file#"$staged/"}"
        target="$destination/$relative"
        if [[ -e "$target" || -L "$target" ]]; then
            if [[ -L "$file" ]]; then
                [[ -L "$target" && "$(readlink "$file")" == "$(readlink "$target")" ]] || return 1
            else
                [[ -f "$target" && ! -L "$target" ]] && cmp -s "$file" "$target" || return 1
            fi
        fi
    done < <(find "$staged" \( -type f -o -type l \) -print0)
    install -d -m 755 "$destination" || return 1
    cp -a "$staged/." "$destination/" || return 1
    mv -T "$source" "$backup" || return 1
    rm -rf "$staged"
}

kos_migrate_home() {
    local home="$1" backup="$2" desktop="$3" automation="$4" namespace directory file
    [[ "$desktop" =~ ^[a-z]+$ && "$automation" =~ ^[a-z]+$ ]] || return 1
    for namespace in "$desktop" "$automation"; do
        for directory in .config .local/state .cache; do
            kos_migrate_tree "$home/$directory/$namespace" "$home/$directory/kos" \
                "$backup/$directory/$namespace" "$desktop" "$automation" "${directory##*/}" || return 1
        done
    done
    for directory in .config/hypr .config/gtk-3.0 .config/gtk-4.0 .config/kitty .config/foot .config/ghostty .config/alacritty .config/environment.d .local/share/applications; do
        [[ -d "$home/$directory" && ! -L "$home/$directory" ]] || continue
        install -d -m 700 "$backup/managed/$(dirname "$directory")" || return 1
        cp -a "$home/$directory" "$backup/managed/$directory" || return 1
        while IFS= read -r -d '' file; do
            kos_migrate_text "$file" "$desktop" "$automation" || return 1
        done < <(find "$home/$directory" -type f -print0)
    done
    for file in .bashrc .bash_profile .profile .config/slack-flags.conf .config/discord-flags.conf; do
        [[ -f "$home/$file" && ! -L "$home/$file" ]] || continue
        install -d -m 700 "$backup/managed/$(dirname "$file")" || return 1
        cp -a "$home/$file" "$backup/managed/$file" || return 1
        kos_migrate_text "$home/$file" "$desktop" "$automation" || return 1
    done
}

kos_migrate_pacman() {
    local config="$1" mirrorlist="$2" desktop="$3" staged
    [[ "$desktop" =~ ^[a-z]+$ && -f "$config" && ! -L "$config" && ! -L "$mirrorlist" ]] || return 1
    staged=$(mktemp "${config%/*}/.kos-pacman.XXXXXX") || return 1
    awk -v section="[$desktop]" '
        /^\[/ { skip=($0 == section) }
        !skip { print }
    ' "$config" > "$staged" || return 1
    chmod --reference="$config" "$staged" || return 1
    mv -fT "$staged" "$config" || return 1
    if [[ -f "$mirrorlist" ]]; then
        sed -i "/$desktop/d" "$mirrorlist" || return 1
        if ! grep -qE '^Server[[:space:]]*=' "$mirrorlist"; then
            printf 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch\n' >> "$mirrorlist" || return 1
        fi
    fi
}
