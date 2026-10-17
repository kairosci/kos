#!/usr/bin/env bash
set -euo pipefail

[[ "${OS_RESTORE_OMARCHY:-0}" == 1 ]] || return 0
source "$PROJECT_DIR/scripts/lib/omarchy-restore.sh"
for _restore_home in /home/*; do
    [[ -d "$_restore_home" && ! -L "$_restore_home" ]] || continue
    _restore_user=${_restore_home##*/}
    omarchy_restore_user "$_restore_user" "$_restore_home" || err "restore.failed" "$_restore_user"
done
