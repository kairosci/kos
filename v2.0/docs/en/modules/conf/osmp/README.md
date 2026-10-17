# OSMP installation

The setup pipeline discovers this installer after application provisioning. It stages only the runtime sources, manifest and canonical license from `modules/plugins/osmp`, validates that standalone payload and installs it with the shared user configuration helpers. Documentation symlinks remain outside the runtime payload, while symlinks in executable sources are rejected. Changed files retain backups. The shell plugin stage refreshes the native catalog; media opens Celluloid from the menu instead of enabling the retired popup.

The local repository is the sole source. No remote URL or separate runtime is required. Apply changes with `make setup` from the repository root.
