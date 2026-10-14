# Application configurations

Every per-application configuration lives under this directory. Configuration installers use `scripts/lib/userconf.sh`.

`fontconfig` owns the filter that keeps web only WOFF2 files out of desktop font matching.

Each installed application owns its configuration directory. `desktop` owns migration of retired integrations and the hidden mpv backend launcher.



Brave Origin owns its native launcher flags in `brave/data/brave-origin-flags.conf`; its existing user profile is retained. Setup automatically executes every `modules/conf/*/install.sh` in each user's environment, so app installers do not require individual stage registrations.

Zed opens project directories directly through `zed --new /path/to/project` or the terminal. OnlyOffice handles office documents, spreadsheets and presentations through its native INI configuration.

Nautilus, Celluloid, Papers, Loupe, Baobab, Resources and File Roller receive native desktop settings. Neovim uses packaged LazyVim for mouse-enabled terminal editing, with simple shortcuts and an F4 settings menu; see [the editor guide](nvim/README.md). Micro is retired with personal configuration preserved. Zed remains the desktop editor and project environment. Each function has one user-facing application. Celluloid's required mpv backend has no separate launcher. Retired gdu personal configurations are retained. Slack and Discord use packaged launchers with automatic Wayland selection and GTK portals. Browser and Electron profiles remain personal. GNOME Keyring provides Secret Service; Seahorse manages its credentials. KeePassXC databases are retained.

`easyeffects` owns the `OS-Subwoofer` output preset, its native activation and desktop autostart. The preset uses conservative bass harmonics, input headroom and a final limiter; see [the audio guide](easyeffects/README.md).

`menubar` owns the native bar dimensions and widget grouping; see [the bar guide](menubar/README.md).
