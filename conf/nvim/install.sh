#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
i18n_init

config="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
data="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
native="${OS_NVIM_SKEL:-/etc/skel}"
for directory in "$config/lua/config" "$config/lua/plugins" "$data/lazy"; do
    while [[ "$directory" != / && "$directory" != . ]]; do
        [[ ! -L "$directory" ]] || err "defaults.app_failed" "Neovim"
        directory=$(dirname "$directory")
    done
done
if [[ ! -e "$config/init.lua" ]]; then
    [[ -f "$native/.config/nvim/init.lua" ]] || err "defaults.app_failed" "omarchy-nvim"
    file_list=$(mktemp)
    trap 'rm -f "$file_list"' EXIT
    find "$native/.config/nvim" -type f -print0 > "$file_list" || err "defaults.app_failed" "omarchy-nvim"
    while IFS= read -r -d '' source_file; do
        destination="$config/${source_file#"$native/.config/nvim/"}"
        directory=$(dirname "$destination")
        while [[ "$directory" != "$config" ]]; do
            [[ ! -L "$directory" ]] || err "defaults.app_failed" "Neovim"
            directory=$(dirname "$directory")
        done
        [[ ! -e "$destination" && ! -L "$destination" ]] || continue
        install_user_file "$source_file" "$destination" || err "defaults.app_failed" "Neovim"
    done < "$file_list"
fi
[[ -f "$config/lua/config/lazy.lua" ]] || err "defaults.app_failed" "LazyVim configuration"
if [[ ! -e "$data/lazy" ]]; then
    [[ -d "$native/.local/share/nvim/lazy" ]] || err "defaults.app_failed" "omarchy-nvim plugins"
    mkdir -p "$data"
    cp -a -- "$native/.local/share/nvim/lazy" "$data/lazy" || err "defaults.app_failed" "omarchy-nvim plugins"
fi
[[ ! -L "$config/lua/plugins/os-ease.lua" ]] || err "defaults.app_failed" "Neovim"
install_user_file "$SCRIPT_DIR/data/os-ease.lua" "$config/lua/plugins/os-ease.lua" || err "defaults.app_failed" "Neovim"
install_shell_block "$HOME/.bashrc" "# >>> os terminal editor >>>" "# <<< os terminal editor <<<" << 'SHELLBLOCK'
export EDITOR=nvim
export VISUAL=nvim
SHELLBLOCK
log "gui.install_done" "Neovim"
