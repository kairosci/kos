# Application configurations

Every per-application configuration lives under this directory. Configuration installers use `scripts/lib/userconf.sh`.

Each installed application owns its configuration directory. `desktop` owns migration of retired integrations and the hidden mpv backend launcher.

Brave Origin owns its native launcher flags in `brave/data/brave-origin-flags.conf`; its existing user profile is retained. Setup automatically executes every `conf/*/install.sh` in each user's environment, so app installers do not require individual stage registrations.

Zed opens project directories directly through `zed --new /path/to/project` or the terminal. OnlyOffice handles office documents, spreadsheets and presentations through its native INI configuration.

Nautilus, Celluloid, Papers, Loupe, Baobab, Resources and File Roller receive native desktop settings. Each function has one user-facing application. Celluloid's required mpv backend has no separate launcher. Retired Micro and gdu personal configurations are retained. Slack and Discord use packaged launchers with automatic Wayland selection and GTK portals. Browser and Electron profiles remain personal. GNOME Keyring provides Secret Service; Seahorse manages its credentials. KeePassXC databases are retained.
