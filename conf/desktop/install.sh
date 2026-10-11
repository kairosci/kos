#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
i18n_init

for tool in micro disk; do
    remove_shell_block "$HOME/.bashrc" "# >>> omaconf $tool >>>" "# <<< omaconf $tool <<<"
done
for hook in micro-theme disk-theme btop-theme; do
    rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/hooks/theme-set.d/$hook"
done
install_user_file "$SCRIPT_DIR/data/mpv.desktop" "${XDG_DATA_HOME:-$HOME/.local/share}/applications/mpv.desktop"
log "gui.install_done" "desktop"
