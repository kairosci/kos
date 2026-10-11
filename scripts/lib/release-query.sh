#!/usr/bin/env bash

kos_release_query() {
    local channel="$1" destination="$2" endpoint status
    case "$channel" in
        stable) endpoint=releases/latest ;;
        preview) endpoint=releases ;;
        *) return 2 ;;
    esac
    status=$(curl --silent --show-error --proto '=https' --write-out '%{http_code}' \
        "https://api.github.com/repos/kairosci/kos/$endpoint" -o "$destination") || return 2
    [[ "$status" != 404 ]] || return 1
    [[ "$status" == 200 ]] || return 2
    if [[ "$channel" == preview ]]; then
        jq -e '[.[] | select(.draft == false)][0] // empty' "$destination" > "$destination.selected" || return 1
        mv "$destination.selected" "$destination" || return 2
    fi
    jq -e 'type == "object" and .draft == false and (.tag_name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' "$destination" >/dev/null || return 2
}
