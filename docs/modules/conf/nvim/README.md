# Neovim

The terminal editor uses Omarchy's packaged LazyVim configuration and cached plugins. Zed remains the graphical editor. Setup seeds missing configuration files, preserves existing personal files and plugin caches, and installs one managed LazyVim extension with backup support. An existing configuration must already use LazyVim; setup refuses to replace an incompatible configuration.

Open a project with `cd /path/to/project` followed by `nvim .`, or open a file with `nvim filename`. Click files in the explorer, use the mouse to select text, resize splits and scroll. Press `i` to type and `Esc` to navigate. Mouse support depends on the terminal. F4 opens a settings menu for configuration files, plugins, extra features and health checks. Configuration files remain ordinary Lua files rather than a graphical preferences form.

| Shortcut | Action |
| --- | --- |
| F1 | Show simple help |
| Ctrl S | Save |
| Ctrl Q | Quit with an unsaved changes prompt |
| Ctrl P | Find a project file |
| Ctrl F | Search the current file |
| F2 | Open the project explorer |
| F3 | Search project content |
| F4 or `:Settings` | Open the editor settings menu |
| Space, then wait | Show available commands in navigation mode |

F1 opens a help window; close it with `q` or `Esc`. In pickers, type to filter, use the arrow keys to move and press Enter to select. Esc cancels a menu without changing settings. For terminal clipboard copy and paste, use Ctrl Shift C and Ctrl Shift V; mouse selection inside Neovim follows the editor's selection behavior.

Use `:Lazy` to manage plugins, `:LazyExtras` to select additional features and `:LazyHealth` to diagnose the editor. Plugins and language servers execute code with your user permissions; review additions and updates. Project-local configuration and modelines are disabled by the OS extension. Personal retired Neovim configurations remain archived and are never automatically restored over the packaged starter.

Apply through `make setup` only after the current live-state freeze is lifted. First launch may download missing plugins or language tools. Upstream references: [LazyVim configuration](https://www.lazyvim.org/configuration) and [installation](https://www.lazyvim.org/installation).
