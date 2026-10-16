#!/usr/bin/env bash
set -euo pipefail
CONFIG="$1/.config"
DATA="$1/.local/share/os/session/data"
POLICY="$2"
FILES=$(mktemp)
trap 'rm -f -- "$FILES"' EXIT
while IFS= read -r id; do
    directory="$CONFIG/omarchy/plugins/$id"
    [[ -d "$directory" ]] || exit 0
    find "$directory" -type f ! -name '*.bak' -print0 >> "$FILES"
done < <(jq -r '.menu.id,.controls.id,.panels[].id' "$POLICY")
[[ -d "$DATA" ]] || exit 0
find "$DATA" -type f ! -name '*.bak' -print0 >> "$FILES"
printf '%s\0' "$CONFIG/omarchy/extensions/os-menu.json" "$CONFIG/omarchy/shell.json" >> "$FILES"
LC_ALL=C sort -z "$FILES" | xargs -0 sha256sum
