#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
locale_init
install_user_file "$SCRIPT_DIR/data/brave-origin-flags.conf" "${XDG_CONFIG_HOME:-$HOME/.config}/brave-origin-flags.conf"
