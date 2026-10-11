#!/usr/bin/env bash

set -euo pipefail

log "desktop.hook_install"
install -Dm644 -o root -g root "$PROJECT_ROOT/scripts/lib/userconf.sh" /usr/local/lib/omaconf/userconf.sh
install -Dm755 "$PROJECT_ROOT/scripts/lib/desktop-cleanup.sh" /usr/local/libexec/omaconf-desktop-cleanup
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/99-omaconf-desktop-cleanup.hook << 'HOOK'
[Trigger]
Operation = Remove
Type = Package
Target = *

[Action]
Description = Sweeping orphan application entries...
When = PostTransaction
Exec = /usr/local/libexec/omaconf-desktop-cleanup
HOOK
chmod 644 /etc/pacman.d/hooks/99-omaconf-desktop-cleanup.hook

log "desktop.sweep"
if [[ -f "$PROJECT_ROOT/scripts/lib/desktop-cleanup.sh" ]]; then
    # shellcheck source=../desktop-cleanup.sh
    source "$PROJECT_ROOT/scripts/lib/desktop-cleanup.sh"
    desktop_cleanup_sweep || warn "desktop.refresh_skipped"
fi
