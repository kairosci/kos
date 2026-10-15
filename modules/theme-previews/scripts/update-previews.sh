#!/usr/bin/env bash
set -euo pipefail

source /usr/local/lib/os/i18n.sh
i18n_init
[[ $EUID -eq 0 ]] || err "__root_required"
export PATH=/usr/bin:/usr/sbin:/bin:/sbin
THEME_POLICY_FILE=/usr/local/lib/os/excluded-themes.list
THEME_POLICY_ROOT=/usr/share/omarchy/themes
THEME_POLICY_HOMES=/home
THEME_POLICY_ARCHIVE=/var/lib/os/retired-themes
THEME_PREVIEW_THEMES_ROOT=/usr/share/omarchy/themes
THEME_PREVIEW_BACKUP_DIR=/var/cache/os/theme-preview-stock
THEME_PREVIEW_OVERLAY_STORE=/var/lib/os/theme-preview-overlay
source /usr/local/lib/os/theme-policy.sh
theme_policy_apply || err "theming.policy_failed"
source /usr/local/lib/os/theme-preview.sh
theme_preview_normalize
