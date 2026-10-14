# OSMP installation

The setup pipeline discovers this installer after application provisioning. It validates `plugins/osmp`, installs its manifest and QML sources with the shared user configuration helpers, and preserves backups of changed files. The shell plugin stage enables `os.osmp` using native Omarchy commands.

The local repository is the sole source. No remote URL or separate runtime is required. Apply changes with `make setup` from the repository root.
