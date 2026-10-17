# OSMP installation

The application registry selects the Lua plugin installer after package provisioning. Native widget sources live in `src/component/media/osmp/src/`; manifest and package metadata live under `data/component/media/osmp/`. The installer stages regular runtime sources, manifest and canonical license, checks matching versions and validates that standalone payload before publication. Repository metadata and documentation links never enter the payload.

Configuration namespace migration checks all collisions before moving personal entries and preserves the native compatibility link. Redirected payload files, destination ancestors and backups are refused before publishing runtime files. Changed regular files retain backups. A failed native validation leaves the installed plugin unchanged.

The local repository is the sole source. `make setup SCOPE=lua-applications` reconciles the Lua application registry. Full setup also refreshes the native plugin catalog and archives the retired identity. Celluloid remains the normal media application; the old popup is not enabled. Native widget changes require shell reconciliation through the privileged pipeline.
