#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/test_lib.sh"
source "$SCRIPT_DIR/../scripts/lib/migration.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
HOME_FIXTURE="$SANDBOX/user home"
BACKUP="$SANDBOX/backup"
mkdir -p "$HOME_FIXTURE/.config/oldwm/hooks" "$HOME_FIXTURE/.config/oldconf" "$HOME_FIXTURE/.config/hypr" "$HOME_FIXTURE/.local/state/oldwm/current" "$HOME_FIXTURE/.config/brave/Default"
printf 'OLDWM_PATH=/usr/share/oldwm\n' > "$HOME_FIXTURE/.config/oldwm/hooks/oldconf-helper"
printf 'private automation state\n' > "$HOME_FIXTURE/.config/oldconf/state"
printf 'require("oldconf-gtk")\n' > "$HOME_FIXTURE/.config/hypr/hyprland.lua"
printf 'source /usr/share/oldwm/default/bash/rc\n' > "$HOME_FIXTURE/.bashrc"
printf 'authenticated browser data\n' > "$HOME_FIXTURE/.config/brave/Default/Preferences"
ln -s "$HOME_FIXTURE/.local/state/oldwm/current/theme" "$HOME_FIXTURE/.local/state/oldwm/current/background"
mkdir -p "$HOME_FIXTURE/Documents"
printf 'oldwm is mentioned in a private document\n' > "$HOME_FIXTURE/Documents/document.txt"
printf "oldwm private clipboard text\n" > "$HOME_FIXTURE/.local/state/oldwm/clipboard-history"
browser_hash=$(sha256sum "$HOME_FIXTURE/.config/brave/Default/Preferences")
document_hash=$(sha256sum "$HOME_FIXTURE/Documents/document.txt")
test_section "kos Namespace Migration"
assert_true "preflight validates all namespace merges without modifying the home" 'kos_migrate_preflight "$HOME_FIXTURE" oldwm oldconf && [[ -d "$HOME_FIXTURE/.config/oldwm" && ! -e "$HOME_FIXTURE/.config/kos" ]]'
assert_true "desktop and automation namespaces merge without collisions" 'kos_migrate_home "$HOME_FIXTURE" "$BACKUP" oldwm oldconf'
assert_true "migrated hooks use the new paths and environment names" 'grep -qx KOS_PATH=/usr/share/kos "$HOME_FIXTURE/.config/kos/hooks/kos-helper"'
assert_true "personal clipboard text remains unchanged" 'grep -qx "oldwm private clipboard text" "$HOME_FIXTURE/.local/state/kos/clipboard-history"'
assert_true "automation state survives the namespace merge" 'grep -qx "private automation state" "$HOME_FIXTURE/.config/kos/state"'
assert_true "managed compositor and shell configuration is rewritten" 'grep -q kos-gtk "$HOME_FIXTURE/.config/hypr/hyprland.lua" && grep -q /usr/share/kos/default/bash/rc "$HOME_FIXTURE/.bashrc"'
assert_true "state symlinks point to the migrated namespace" '[[ "$(readlink "$HOME_FIXTURE/.local/state/kos/current/background")" == "$HOME_FIXTURE/.local/state/kos/current/theme" ]]'
assert_true "original namespaces remain in private rollback backups" '[[ -d "$BACKUP/.config/oldwm" && -d "$BACKUP/.config/oldconf" && ! -e "$HOME_FIXTURE/.config/oldwm" && ! -e "$HOME_FIXTURE/.config/oldconf" && $(stat -c %a "$BACKUP/.config") == 700 ]]'
assert_true "browser authentication and personal documents are untouched" '[[ "$browser_hash" == "$(sha256sum "$HOME_FIXTURE/.config/brave/Default/Preferences")" && "$document_hash" == "$(sha256sum "$HOME_FIXTURE/Documents/document.txt")" ]]'
assert_true "repeating migration is stable" 'kos_migrate_home "$HOME_FIXTURE" "$SANDBOX/repeated" oldwm oldconf && grep -qx KOS_PATH=/usr/share/kos "$HOME_FIXTURE/.config/kos/hooks/kos-helper"'
mkdir -p "$SANDBOX/conflict/source" "$SANDBOX/conflict/destination"
printf 'original\n' > "$SANDBOX/conflict/source/value"
printf 'independent customization\n' > "$SANDBOX/conflict/destination/value"
assert_false "conflicting kos customization is not overwritten" 'kos_migrate_tree "$SANDBOX/conflict/source" "$SANDBOX/conflict/destination" "$SANDBOX/conflict/backup" oldwm oldconf'
assert_true "a conflict preserves both source and target" 'grep -qx original "$SANDBOX/conflict/source/value" && grep -qx "independent customization" "$SANDBOX/conflict/destination/value"'
ln -s "$SANDBOX/conflict/destination" "$SANDBOX/linked"
assert_false "directory symlinks cannot redirect privileged migration" 'kos_migrate_tree "$SANDBOX/linked" "$SANDBOX/target" "$SANDBOX/linked-backup" oldwm oldconf'
mkdir -p "$SANDBOX/pacman"
printf '[options]\nParallelDownloads = 5\n[oldwm]\nServer = https://packages.oldwm.invalid\n[extra]\nInclude = /etc/pacman.d/mirrorlist\n[custom]\nServer = https://custom.invalid\n' > "$SANDBOX/pacman/pacman.conf"
printf 'Server = https://mirror.oldwm.invalid/$repo/os/$arch\n' > "$SANDBOX/pacman/mirrorlist"
assert_true "migration removes only the previous distribution repository" 'kos_migrate_pacman "$SANDBOX/pacman/pacman.conf" "$SANDBOX/pacman/mirrorlist" oldwm && ! grep -q oldwm "$SANDBOX/pacman/pacman.conf" && grep -q "\[custom\]" "$SANDBOX/pacman/pacman.conf" && grep -q "\[extra\]" "$SANDBOX/pacman/pacman.conf"'
assert_true "empty retired mirrors become a real Arch mirror" 'grep -qx '\''Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch'\'' "$SANDBOX/pacman/mirrorlist"'
assert_false "invalid namespace input is rejected before editing files" 'kos_migrate_pacman "$SANDBOX/pacman/pacman.conf" "$SANDBOX/pacman/mirrorlist" "../invalid"'
test_summary
