#!/usr/bin/env bash

set -euo pipefail

OS_DISPATCHER="$PROJECT_DIR/modules/os/bin/os"
OS_CHANGELOG_SRC="$PROJECT_DIR/CHANGELOG.md"
OS_APP_LIBRARY="$PROJECT_DIR/modules/os/scripts/lib/app-launch.sh"
OS_APP_POLICY="$PROJECT_DIR/modules/os/data/app-launch.json"

[[ -f "$OS_DISPATCHER" ]] || err "os.dispatch_failed" "$OS_DISPATCHER"
[[ -f "$OS_CHANGELOG_SRC" ]] || err "os.changelog_missing" "$OS_CHANGELOG_SRC"
[[ -r "$OS_APP_LIBRARY" && -r "$OS_APP_POLICY" ]] || err "os.dispatch_failed" "os app"

install -d -m 755 /usr/share/os || err "os.dispatch_failed" "/usr/share/os"
install -d -m 755 /usr/share/os/lib/messages /usr/share/os/data || err "os.dispatch_failed" "/usr/share/os"
install -m 644 "$OS_APP_LIBRARY" "$PROJECT_DIR/scripts/lib/i18n.sh" /usr/share/os/lib/ || err "os.dispatch_failed" "/usr/share/os/lib"
install -m 644 "$OS_APP_POLICY" /usr/share/os/data/ || err "os.dispatch_failed" "/usr/share/os/data"
install -m 644 "$PROJECT_DIR"/data/catalog/*.msg /usr/share/os/lib/messages/ || err "os.dispatch_failed" "/usr/share/os/lib/messages"
install -m 644 "$OS_CHANGELOG_SRC" /usr/share/os/CHANGELOG.md || err "os.changelog_missing" "/usr/share/os/CHANGELOG.md"
log "os.changelog_installed" "/usr/share/os/CHANGELOG.md"
install -m 755 "$OS_DISPATCHER" /usr/local/bin/os || err "os.dispatch_failed" "/usr/local/bin/os"
log "os.cli_installed" "/usr/local/bin/os"

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
