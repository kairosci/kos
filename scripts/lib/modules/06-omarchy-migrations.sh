#!/usr/bin/env bash
set -euo pipefail

[[ "${OS_RUN_MIGRATIONS:-0}" == 1 ]] || return 0
source "$PROJECT_DIR/scripts/lib/retired-config.sh"
for _migration_home in /home/*; do
    [[ -d "$_migration_home" && ! -L "$_migration_home" ]] || continue
    _migration_user=${_migration_home##*/}
    if ! pacman -Q omarchy-nvim >/dev/null 2>&1; then
        retire_user_config "$_migration_user" "$_migration_home" nvim || err "restore.failed" "$_migration_user"
    fi
    omarchy_as "$_migration_user" migrate || err "restore.failed" "$_migration_user"
done
