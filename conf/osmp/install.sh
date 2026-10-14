#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
i18n_init

SOURCE="$PROJECT_DIR/plugins/osmp"
TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/os.osmp"
[[ ! -L "$TARGET" ]] || err "defaults.app_failed" "osmp"
omarchy plugin validate "$SOURCE"
for file in "$SOURCE"/src/* "$SOURCE/manifest.json" "$SOURCE/LICENSE"; do
    relative="${file#"$SOURCE"/}"
    [[ ! -L "$TARGET/$relative" ]] || err "defaults.app_failed" "osmp"
    install_user_file "$file" "$TARGET/$relative"
done
log "gui.install_done" "osmp"
