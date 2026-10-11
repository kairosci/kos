#!/usr/bin/env bash
set -euo pipefail

source /usr/local/lib/omaconf/i18n.sh
i18n_init
[[ $EUID -eq 0 ]] || err "__root_required"
source /usr/local/lib/omaconf/theme-preview.sh
theme_preview_normalize
