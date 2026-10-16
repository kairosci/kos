#!/usr/bin/env bash

Os::scripts::lib::modules::35_shell_plugins_sh::run() {

set -euo pipefail

log "shell_plugins.install"
for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    _legacy="$user_home/.config/os/plugins/krosci.omamp"
    if [[ -e "$_legacy" || -L "$_legacy" ]]; then
        omarchy_as "$_user" plugin disable krosci.omamp || err "defaults.app_failed" "osmp"
        user_as "$_user" bash -c '
            set -euo pipefail
            archive="$HOME/.local/state/os/retired-plugins"
            mkdir -p "$archive"
            destination=$(mktemp -d "$archive/omamp.XXXXXX")
            mv "$1" "$destination/plugin"
        ' bash "$_legacy" || err "defaults.app_failed" "osmp"
    fi
    omarchy_as "$_user" shell shell rescanPlugins || err "defaults.app_failed" "osmp"
    omarchy_as "$_user" plugin enable os.media || err "defaults.app_failed" "osmp"
done

}

Os::scripts::lib::modules::35_shell_plugins_sh::run "$@"
