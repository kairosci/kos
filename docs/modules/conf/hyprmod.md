# Hyprland settings

HyprMod provides a native GTK4 and libadwaita graphical interface for the Lua based Hyprland configuration. Open HyprMod from Apps or with Super+comma. It offers searchable compositor settings, monitor layouts, keyboard and mouse preferences, shortcuts, window and layer rules and workspaces. Its preview, pending changes, save and undo controls avoid manual configuration editing. Changes are saved in `~/.config/hypr/hyprland-gui.lua`, loaded after the managed desktop defaults; setup preserves that file.

The installed application is upstream HyprMod 0.5.0 from a fixed commit archive. The source and every pure Python library wheel carry SHA-256 hashes in the requirements lock. GTK, libadwaita, Python Cairo, PyGObject, the build backend and uv remain pacman packages. Provisioning is native Bash; Python is an application runtime. No remote install script is executed, no global pip environment is modified and no GNOME Shell dependency is introduced. Updating the lock is a reviewed repository change. The application environment is recreated when its lock or system Python version changes.

Run `make setup SCOPE=settings` to provision the package dependencies, install the application and validate the staged Lua configuration before applying the include and shortcut. Existing configuration backups use the shared user configuration helpers. Opening and using the GUI is an explicit user action; its automatic settings writes do not authorize agents to bypass the setup pipeline.

HyprMod configures the compositor. Wi-Fi, Bluetooth, audio, printing and other system services remain separate applications or native system controls; it is not a replacement for those backends. GTK and libadwaita styling follow the system palette through the existing theme integration.

Sources: [HyprMod](https://github.com/BlueManCZ/hyprmod), [pinned release](https://github.com/BlueManCZ/hyprmod/tree/e148d221cc62edaa8d1b8ffac0f0a57edcb8e3c1).

Interface dimensions and spacing are managed as JSON, separate from the exact patch applied to the pinned app source. Symbolic icons use the installed Adwaita family and the system palette. Setup preserves explicit auto-save preferences. See [desktop interface](../../desktop-interface.md).
