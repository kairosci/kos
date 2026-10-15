#!/usr/bin/env bash

set -euo pipefail

OS_FONTCONFIG_SOURCE="$PROJECT_DIR/conf/fontconfig/data/99-os-reject-woff2.conf"
OS_FONTCONFIG_TARGET=/etc/fonts/conf.d/99-os-reject-woff2.conf
[[ -f "$OS_FONTCONFIG_SOURCE" ]] || err "setup.stage_missing" "$OS_FONTCONFIG_SOURCE"
OS_FONTCONFIG_UPDATED=0

if ! cmp -s "$OS_FONTCONFIG_SOURCE" "$OS_FONTCONFIG_TARGET"; then
    install -Dm644 -o root -g root "$OS_FONTCONFIG_SOURCE" "$OS_FONTCONFIG_TARGET"
    OS_FONTCONFIG_UPDATED=1
fi

if [[ "$OS_FONTCONFIG_UPDATED" == 1 || "${SETUP_SCOPE:-}" == fontconfig ]]; then
    fc-cache -f
fi

for OS_FONTCONFIG_FAMILY in sans-serif "Noto Sans" "JetBrains Mono"; do
    OS_FONTCONFIG_MATCH=$(fc-match -f '%{file}' "$OS_FONTCONFIG_FAMILY") || err "fontconfig.match_failed" "$OS_FONTCONFIG_FAMILY"
    [[ "$OS_FONTCONFIG_MATCH" != /usr/share/fonts/WOFF2/* ]] || err "fontconfig.match_failed" "$OS_FONTCONFIG_FAMILY"
done
