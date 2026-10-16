#!/usr/bin/env bash
set -euo pipefail

_applications=$(jq -er 'keys | if length > 0 then .[] else empty end' "$PROJECT_DIR/data/component/application/policy.json") || err "defaults.app_failed" "application policy"
for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    while IFS= read -r _application; do
        user_as "$_user" lua -E "$PROJECT_DIR/src/main.lua" "$PROJECT_DIR" apply-settings "$_application" || err "defaults.app_failed" "$_application"
    done <<< "$_applications"
    for _installer in "$PROJECT_DIR"/modules/conf/*/install.sh; do
        [[ -f "$_installer" ]] || continue
        user_as "$_user" bash "$_installer" || err "defaults.app_failed" "$(basename "$(dirname "$_installer")")"
    done
done
