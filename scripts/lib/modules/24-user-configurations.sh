#!/usr/bin/env bash
set -euo pipefail

for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    for _installer in "$PROJECT_DIR"/modules/conf/*/install.sh; do
        [[ -f "$_installer" ]] || continue
        user_as "$_user" bash "$_installer" || err "defaults.app_failed" "$(basename "$(dirname "$_installer")")"
    done
done
