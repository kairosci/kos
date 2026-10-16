#!/usr/bin/env bash

Os::scripts::lib::retired_config_sh::run() {

retire_user_config() {
    local user="$1" home="$2" app="$3" source target directory
    [[ "$app" =~ ^[a-z][a-z0-9_-]*$ ]] || return 1
    [[ -d "$home" && ! -L "$home" && ! -L "$home/.config" ]] || return 1
    source="$home/.config/$app"
    [[ ! -L "$source" ]] || return 1
    [[ -d "$source" ]] || return 0
    target="$home/.local/state/omarchy/retired"
    for directory in "$home/.local" "$home/.local/state" "$home/.local/state/omarchy" "$target"; do
        [[ ! -L "$directory" ]] || return 1
    done
    install -d -m 700 -o "$user" -g "$user" "$target" || return 1
    target=$(mktemp -d "$target/$app.XXXXXX") || return 1
    mv "$source" "$target/config" || return 1
    chown -R --no-dereference "$user:$user" "$target" || return 1
}

}

Os::scripts::lib::retired_config_sh::run "$@"
