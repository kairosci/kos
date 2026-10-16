#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
assert_true "Neovim shortcuts dispatch settings and cancel safely" "lua '$SCRIPT_DIR/nvim-ease.lua' '$PROJECT_DIR/modules/conf/nvim/data/os-ease.lua'"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home" XDG_CONFIG_HOME="$SANDBOX/home/.config" XDG_DATA_HOME="$SANDBOX/home/.local/share" OS_NVIM_SKEL="$SANDBOX/skel"
mkdir -p "$HOME" "$OS_NVIM_SKEL/.config/nvim/lua/config" "$OS_NVIM_SKEL/.local/share/nvim/lazy/example"
printf '%s\n' 'require("config.lazy")' > "$OS_NVIM_SKEL/.config/nvim/init.lua"
printf '%s\n' 'return {}' > "$OS_NVIM_SKEL/.config/nvim/lua/config/lazy.lua"
printf '%s\n' 'cached plugin' > "$OS_NVIM_SKEL/.local/share/nvim/lazy/example/keep"
touch "$HOME/.bashrc"
assert_true "Neovim seeds the packaged starter and cache" "bash '$PROJECT_DIR/modules/conf/nvim/install.sh'"
assert_file_contains_literal "Neovim selects the terminal editor" "$HOME/.bashrc" 'export EDITOR=nvim'
printf '%s\n' 'personal options' > "$XDG_CONFIG_HOME/nvim/lua/config/options.lua"
printf '%s\n' 'personal cache' > "$XDG_DATA_HOME/nvim/lazy/example/keep"
assert_true "Neovim repeated install succeeds" "bash '$PROJECT_DIR/modules/conf/nvim/install.sh'"
assert_file_contains_literal "Neovim preserves personal options" "$XDG_CONFIG_HOME/nvim/lua/config/options.lua" 'personal options'
assert_file_contains_literal "Neovim preserves existing plugin cache" "$XDG_DATA_HOME/nvim/lazy/example/keep" 'personal cache'
assert_true "Neovim installer is idempotent" "before=\$(sha256sum '$HOME/.bashrc' '$XDG_CONFIG_HOME/nvim/lua/modules/plugins/os-ease.lua'); bash '$PROJECT_DIR/modules/conf/nvim/install.sh'; [[ \"\$before\" == \"\$(sha256sum '$HOME/.bashrc' '$XDG_CONFIG_HOME/nvim/lua/modules/plugins/os-ease.lua')\" ]]"
mv "$XDG_CONFIG_HOME/nvim/lua/plugins" "$SANDBOX/plugins"
ln -s "$SANDBOX/plugins" "$XDG_CONFIG_HOME/nvim/lua/plugins"
assert_false "Neovim rejects redirected plugin directories" "bash '$PROJECT_DIR/modules/conf/nvim/install.sh'"
rm "$XDG_CONFIG_HOME/nvim/lua/plugins"
mv "$SANDBOX/plugins" "$XDG_CONFIG_HOME/nvim/lua/plugins"
rm "$XDG_CONFIG_HOME/nvim/lua/config/lazy.lua"
assert_false "Neovim refuses incompatible personal configurations" "bash '$PROJECT_DIR/modules/conf/nvim/install.sh'"
test_summary
