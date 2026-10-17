#!/usr/bin/env bash
set -euo pipefail

"$PROJECT_DIR/script/os-lua" install-cli
for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    id "$_user" >/dev/null 2>&1 || { warn "os.cli_skipped" "$_user"; continue; }
    user_as "$_user" "$PROJECT_DIR/script/os-lua" install-cli-user || warn "os.cli_skipped" "$_user"
done
