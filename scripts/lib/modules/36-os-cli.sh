#!/usr/bin/env bash

Os::scripts::lib::modules::36_os_cli_sh::run() {

set -euo pipefail

OS_DISPATCHER="$PROJECT_DIR/modules/os/bin/os"
OS_CHANGELOG_SRC="$PROJECT_DIR/CHANGELOG.md"

[[ -f "$OS_DISPATCHER" ]] || err "os.dispatch_failed" "$OS_DISPATCHER"
[[ -f "$OS_CHANGELOG_SRC" ]] || err "os.changelog_missing" "$OS_CHANGELOG_SRC"

install -m 755 "$OS_DISPATCHER" /usr/local/bin/os || err "os.dispatch_failed" "/usr/local/bin/os"
log "os.cli_installed" "/usr/local/bin/os"

install -d -m 755 /usr/share/os || err "os.dispatch_failed" "/usr/share/os"
install -m 644 "$OS_CHANGELOG_SRC" /usr/share/os/CHANGELOG.md || err "os.changelog_missing" "/usr/share/os/CHANGELOG.md"
log "os.changelog_installed" "/usr/share/os/CHANGELOG.md"

for user_home in /home/*; do
    [[ -d "$user_home" ]] || continue
    _user=$(basename "$user_home")
    id "$_user" >/dev/null 2>&1 || { warn "os.cli_skipped" "$_user"; continue; }
    user_as "$_user" bash -c '
        set -euo pipefail
        mkdir -p "$HOME/.local/bin" "$HOME/.local/share/os"
        install -m 755 /usr/local/bin/os "$HOME/.local/bin/os"
        install -m 644 /usr/share/os/CHANGELOG.md "$HOME/.local/share/os/CHANGELOG.md"
    ' || warn "os.cli_skipped" "$_user"
done

}

Os::scripts::lib::modules::36_os_cli_sh::run "$@"
