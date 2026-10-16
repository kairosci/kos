#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
STATE=$(mktemp)
trap 'rm -f -- "$STATE"' EXIT
if [[ -f "${2:-}" ]]; then
    jq -e 'type == "object" and all(to_entries[]; (.key | length > 0) and (.value | type == "string"))' "$2" > /dev/null
    jq -j 'to_entries[] | .key,"\u0000",.value,"\u0000"' "$2" > "$STATE"
fi
lua "$SCRIPT_DIR/clean.lua" "$1" "$STATE" "${3:-}"
