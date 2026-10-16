#!/usr/bin/env bash
set -euo pipefail

easyeffects_apply_preset() {
    local previous loaded
    previous=$(timeout 15 easyeffects --last-loaded-preset output) || err "defaults.app_failed" "EasyEffects preset query"
    if [[ -f "$STATE/default-applied" && "$previous" != "$PRESET" ]]; then
        return 0
    fi
    if timeout 15 easyeffects --load-preset "$PRESET" &&
        loaded=$(timeout 15 easyeffects --last-loaded-preset output) && [[ "$loaded" == "$PRESET" ]]; then
        install_user_content "$STATE/default-applied" 600 <<< "$PRESET" || err "defaults.app_failed" "$PRESET"
    else
        timeout 15 easyeffects --bypass 1 || warn "defaults.app_failed" "EasyEffects bypass"
        err "defaults.app_failed" "$PRESET"
    fi
}
