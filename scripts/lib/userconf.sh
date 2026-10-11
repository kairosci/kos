#!/usr/bin/env bash

install_user_file() {
    local src="$1" dest="$2" mode="${3:-644}"
    [[ -f "$src" ]] || return 0
    mkdir -p "$(dirname "$dest")" || return 1
    if [[ -f "$dest" ]]; then
        if cmp -s "$src" "$dest"; then
            chmod "$mode" "$dest" || return 1
            return 0
        fi
        [[ ! -L "$dest.bak" ]] || return 1
        cp -T "$dest" "$dest.bak" || return 1
    fi
    install -m "$mode" "$src" "$dest"
}

install_user_content() {
    local dest="$1" mode="${2:-644}" tmp
    mkdir -p "$(dirname "$dest")" || return 1
    tmp="$(mktemp "$dest.tmp.XXXXXX")" || return 1
    if ! cat > "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    if [[ -f "$dest" ]]; then
        if cmp -s "$tmp" "$dest"; then
            rm -f "$tmp"
            chmod "$mode" "$dest" || return 1
            if [[ "$mode" == 600 && -e "$dest.bak" ]]; then
                [[ -f "$dest.bak" && ! -L "$dest.bak" ]] || return 1
                chmod "$mode" "$dest.bak" || return 1
            fi
            return 0
        fi
        if [[ -L "$dest.bak" ]] || ! cp -T "$dest" "$dest.bak" || ! chmod "$mode" "$dest.bak"; then
            rm -f "$tmp"
            return 1
        fi
    fi
    if ! chmod "$mode" "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    mv "$tmp" "$dest"
}

merge_user_ini() {
    local src="$1" dest="$2" mode="${3:-644}" staged current=/dev/null
    [[ -r "$src" ]] || return 1
    [[ ! -f "$dest" ]] || current="$dest"
    staged=$(mktemp) || return 1
    if ! awk '
        FNR == NR {
            if ($0 ~ /^\[/) {
                section=$0
                if (!(section in sections)) order[++count]=section
                sections[section]=1
            } else if ($0 ~ /^[^#;=]+=/) {
                key=$0; sub(/=.*/, "", key)
                keys[section, ++lengths[section]]=key
                values[section, key]=$0
            }
            next
        }
        function emit(section, i) {
            if (section in emitted) return
            for (i=1; i<=lengths[section]; i++) print values[section, keys[section, i]]
            emitted[section]=1
        }
        /^\[/ { section=$0; print; emit(section); next }
        /^[^#;=]+=/ {
            key=$0; sub(/=.*/, "", key)
            if ((section, key) in values) next
        }
        { print }
        END {
            for (i=1; i<=count; i++) {
                section=order[i]
                if (!(section in emitted)) { print section; emit(section) }
            }
        }
    ' "$src" "$current" > "$staged"; then
        rm -f "$staged"
        return 1
    fi
    if install_user_content "$dest" "$mode" < "$staged"; then
        rm -f "$staged"
    else
        rm -f "$staged"
        return 1
    fi
}

apply_user_gsettings() {
    local src="$1" schema key value
    while IFS=$'\t' read -r schema key value; do
        [[ -n "$schema" ]] || continue
        gsettings set "$schema" "$key" "$value" || return 1
    done < "$src"
}

install_user_electron_launcher() {
    local src="$1" dest="$2" staged
    [[ -r "$src" ]] || return 1
    staged=$(mktemp) || return 1
    if ! awk '
        /^Exec=/ {
            sub(/^Exec=/, "Exec=env GTK_USE_PORTAL=1 ")
        }
        { print }
    ' "$src" > "$staged"; then
        rm -f "$staged"
        return 1
    fi
    if install_user_content "$dest" < "$staged"; then
        rm -f "$staged"
    else
        rm -f "$staged"
        return 1
    fi
}

remove_shell_block() {
    local rc="$1" begin="$2" end="$3" staged
    [[ -f "$rc" ]] || return 0
    staged=$(mktemp) || return 1
    if ! awk -v begin="$begin" -v end="$end" '
        $0 == begin { if (skip) exit 1; skip=1; next }
        $0 == end { if (!skip) exit 1; skip=0; next }
        !skip { print }
        END { if (skip) exit 1 }
    ' "$rc" > "$staged"; then
        rm -f "$staged"
        return 1
    fi
    if install_user_content "$rc" "$(stat -c %a "$rc")" < "$staged"; then
        rm -f "$staged"
    else
        rm -f "$staged"
        return 1
    fi
}

install_shell_block() {
    local rc="$1" begin="$2" end="$3" block
    [[ -f "$rc" ]] || return 0
    block="$(cat)"
    local staged
    staged="$(mktemp)" || return 1
    awk -v begin="$begin" -v end="$end" '
        index($0, begin) { skip = 1; next }
        skip && index($0, end) { skip = 0; next }
        skip { next }
        { body[++kept] = $0 }
        END {
            last = kept
            while (last > 0 && body[last] ~ /^[[:space:]]*$/) last--
            for (i = 1; i <= last; i++) print body[i]
        }
    ' "$rc" > "$staged"
    if [[ -s "$staged" ]]; then
        printf '\n' >> "$staged"
    fi
    printf '%s\n%s\n%s\n' "$begin" "$block" "$end" >> "$staged"
    if ! cmp -s "$staged" "$rc"; then
        cat "$staged" > "$rc"
    fi
    rm -f "$staged"
}
