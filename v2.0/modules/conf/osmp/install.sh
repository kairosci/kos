#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
locale_init

SOURCE="$PROJECT_DIR/modules/plugins/osmp"
TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/os/plugins/os.osmp"
migrate_user_config_dir "$HOME"
[[ ! -L "$TARGET" ]] || err "defaults.app_failed" "osmp"
STAGE=$(mktemp -d)
trap 'rm -rf -- "$STAGE"' EXIT
[[ -d "$SOURCE/src" && ! -L "$SOURCE/src" ]] || err "defaults.app_failed" "osmp"
for file in "$SOURCE"/src/* "$SOURCE/manifest.json"; do
    [[ -f "$file" && ! -L "$file" ]] || err "defaults.app_failed" "osmp"
    relative="${file#"$SOURCE"/}"
    install_user_file "$file" "$STAGE/$relative"
done
license="$PROJECT_DIR/docs/en/modules/plugins/osmp/LICENSE"
[[ -f "$license" && ! -L "$license" ]] || err "defaults.app_failed" "osmp"
install_user_file "$license" "$STAGE/LICENSE"
omarchy plugin validate "$STAGE"
for file in "$STAGE"/src/* "$STAGE/manifest.json" "$STAGE/LICENSE"; do
    relative="${file#"$STAGE"/}"
    [[ ! -L "$TARGET/$relative" ]] || err "defaults.app_failed" "osmp"
    install_user_file "$file" "$TARGET/$relative"
done
log "gui.install_done" "osmp"
