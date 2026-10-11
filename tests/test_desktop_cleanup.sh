#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIB="$PROJECT_DIR/scripts/lib/desktop-cleanup.sh"

source "$SCRIPT_DIR/test_lib.sh"

log() { :; }
warn() { :; }

test_section "Orphan Launcher Entry Sweep"

assert_file_exists "desktop cleanup library exists" "$LIB"
assert_file_executable "desktop cleanup library executable" "$LIB"
assert_true "desktop cleanup library parses" "bash -n '$LIB'"
assert_true "desktop cleanup library has no failure suppression" "! grep -qE '[|][|][[:space:]]*true([^[:alnum:]_]|$)' '$LIB'"
assert_true "desktop cleanup library never exits the sourcing shell" "! grep -qE '^[[:space:]]*exit' '$LIB'"
assert_file_contains "library resolves wrapped executables" "$LIB" "desktop_cleanup_resolve_target"
assert_file_contains "library detects missing executables" "$LIB" "desktop_cleanup_exec_missing"
assert_file_contains "library detects duplicate application entries" "$LIB" "desktop_cleanup_duplicate"
assert_file_contains "library drops foot without its binary" "$LIB" "foot.desktop"
assert_file_contains "library drops docker without lazydocker" "$LIB" "lazydocker"
assert_file_contains "library refreshes the desktop database" "$LIB" "update-desktop-database"
assert_file_contains "library restores user ownership" "$LIB" "desktop.chown_skipped"

assert_file_contains "debloat module sweeps orphan entries" "$PROJECT_DIR/scripts/lib/modules/10-debloat.sh" "desktop-cleanup.sh"
assert_file_contains "debloat module runs the sweep" "$PROJECT_DIR/scripts/lib/modules/10-debloat.sh" "desktop_cleanup_sweep"
assert_file_contains "defaults module sweeps orphan entries" "$PROJECT_DIR/scripts/lib/modules/20-defaults.sh" "desktop_cleanup_sweep"
assert_file_contains "desktop module installs the cleanup helper" "$PROJECT_DIR/scripts/lib/modules/25-desktop-cleanup.sh" "omaconf-desktop-cleanup"
assert_file_contains "desktop module hooks package removal" "$PROJECT_DIR/scripts/lib/modules/25-desktop-cleanup.sh" "Operation = Remove"
assert_file_contains "desktop module runs the general sweep" "$PROJECT_DIR/scripts/lib/modules/25-desktop-cleanup.sh" "desktop_cleanup_sweep"
assert_file_contains "setup pipeline loads the desktop module" "$PROJECT_DIR/scripts/setup.sh" "25-desktop-cleanup.sh"
assert_file_contains "post-update hook reapplies the entry sweep" "$PROJECT_DIR/hooks/post-update.d/99-omaconf-persist" "omaconf-desktop-cleanup"
assert_file_contains "verify checks foot orphans" "$PROJECT_DIR/scripts/verify.sh" "check.desktop_no_foot"
assert_file_contains "verify validates the disk entry" "$PROJECT_DIR/scripts/verify.sh" "disk_entry_valid"
assert_file_contains "verify checks docker orphans" "$PROJECT_DIR/scripts/verify.sh" "check.desktop_no_docker"
assert_file_contains "verify checks the cleanup hook" "$PROJECT_DIR/scripts/verify.sh" "check.desktop_hook"
assert_file_contains "test runner includes the desktop suite" "$PROJECT_DIR/tests/run-all.sh" "test_desktop_cleanup.sh"

# shellcheck source=../scripts/lib/desktop-cleanup.sh
source "$LIB"

DC_SANDBOX="$(mktemp -d)"
DC_SYS="$DC_SANDBOX/sys"
DC_HOMES="$DC_SANDBOX/homes"
DC_BIN="$DC_SANDBOX/bin"
mkdir -p "$DC_SYS" "$DC_HOMES/tester/.local/share/applications" "$DC_HOMES/tester/.config" "$DC_BIN"
printf '#!/bin/bash\necho fake-gdu\n' > "$DC_BIN/gdu"
chmod +x "$DC_BIN/gdu"

printf '%s\n' '[Desktop Entry]' 'Type=Application' 'TryExec=foot' 'Exec=foot' 'Name=Foot' > "$DC_SYS/foot.desktop"
printf '%s\n' '[Desktop Entry]' 'Version=1.0' 'Name=Disk Usage' 'Exec=xdg-terminal-exec --app-id=TUI.float -e bash -c "dua i /"' 'Type=Application' > "$DC_SYS/Disk Usage.desktop"
printf '%s\n' '[Desktop Entry]' 'Version=1.0' 'Name=Docker' 'Exec=xdg-terminal-exec --app-id=TUI.tile -e omarchy-launch-docker-tui' 'Type=Application' > "$DC_SYS/Docker.desktop"
printf '%s\n' '[Desktop Entry]' 'Name=KeepMe' 'Exec=/usr/bin/true' 'Type=Application' > "$DC_SYS/keep.desktop"
printf '%s\n' '[Desktop Entry]' 'Name=Gone' 'Exec=/nonexistent-omaconf-app-xyz --foo' 'Type=Application' > "$DC_HOMES/tester/.local/share/applications/gone.desktop"
printf '%s\n' '[Default Applications]' 'inode/directory=yazi-terminal.desktop;foot.desktop;' > "$DC_HOMES/tester/.config/mimeapps.list"

export OMACONF_OMARCHY_APPS_DIR="$DC_SYS"
export OMACONF_HOMES_ROOT="$DC_HOMES"
export OMACONF_SYSTEM_APPS_DIRS="$DC_SANDBOX/sysapps"
export OMACONF_DESKTOP_SKIP_REFRESH=1
export PATH="$DC_BIN:/usr/bin:/bin"
mkdir -p "$DC_SANDBOX/sysapps"

assert_true "wrapped dua line resolves to dua" "[[ \"\$(desktop_cleanup_resolve_target 'xdg-terminal-exec --app-id=TUI.float -e bash -c \"dua i /\"')\" == dua ]]"
assert_true "plain binary resolves directly" "[[ \"\$(desktop_cleanup_resolve_target '/usr/bin/true')\" == /usr/bin/true ]]"
assert_true "foot entry is reported missing without its binary" "desktop_cleanup_exec_missing '$DC_SYS/foot.desktop'"
assert_true "valid entry is not reported missing" "! desktop_cleanup_exec_missing '$DC_SYS/keep.desktop'"

mkdir -p "$DC_HOMES/tester/.local/bin"
printf "#!/bin/bash\nexit 0\n" > "$DC_HOMES/tester/.local/bin/sample-editor"
chmod 755 "$DC_HOMES/tester/.local/bin/sample-editor"
printf "%s\n" "[Desktop Entry]" "Type=Application" "Name=Projects" "TryExec=sample-editor" "Exec=sample-editor %f" > "$DC_HOMES/tester/.local/share/applications/sample-editor.desktop"
desktop_cleanup_sweep
assert_file_exists "user launchers retain executables in their own local bin" "$DC_HOMES/tester/.local/share/applications/sample-editor.desktop"
assert_false "user executable paths do not leak into root lookup" "command -v sample-editor"

assert_true "foot orphan removed from the system entries" "[[ ! -f '$DC_SYS/foot.desktop' ]]"
assert_true "docker orphan removed without lazydocker" "[[ ! -f '$DC_SYS/Docker.desktop' ]]"
assert_false "legacy disk alias is removed" "[[ -f '$DC_SYS/Disk Usage.desktop' ]]"
assert_true "valid entry kept" "[[ -f '$DC_SYS/keep.desktop' ]]"
assert_true "user orphan removed" "[[ ! -f '$DC_HOMES/tester/.local/share/applications/gone.desktop' ]]"
assert_true "mimeapps reference cleaned" "! grep -q 'foot.desktop' '$DC_HOMES/tester/.config/mimeapps.list'"
assert_true "mimeapps keeps the valid default" "grep -q 'yazi-terminal.desktop' '$DC_HOMES/tester/.config/mimeapps.list'"

DC_BEFORE="$(md5sum "$DC_SYS"/*.desktop 2>/dev/null)"
desktop_cleanup_sweep
DC_AFTER="$(md5sum "$DC_SYS"/*.desktop 2>/dev/null)"
assert_equal "sweep is idempotent" "$DC_BEFORE" "$DC_AFTER"

printf '%s\n' '[Desktop Entry]' 'Name=AlsoGone' 'TryExec=/nonexistent-omaconf-tryexec' 'Exec=/usr/bin/true' 'Type=Application' > "$DC_HOMES/tester/.local/share/applications/alsogone.desktop"

DC_SYSAPPS="$DC_SANDBOX/sysapps-case"
DC_FAKEBIN="$DC_SANDBOX/fakebin"
mkdir -p "$DC_SYSAPPS" "$DC_FAKEBIN"
printf '%s\n' '[Desktop Entry]' 'Name=ValidUnowned' 'Exec=/usr/bin/true' 'Type=Application' > "$DC_SYSAPPS/valid.desktop"
printf '%s\n' '[Desktop Entry]' 'Name=OrphanUnowned' 'Exec=/nonexistent-omaconf-xyz' 'Type=Application' > "$DC_SYSAPPS/orphan.desktop"
printf '%s\n' '[Desktop Entry]' 'Name=Protected' 'Exec=/nonexistent-omaconf-xyz' 'Type=Application' > "$DC_SYSAPPS/protected.desktop"
printf '%s\n' '#!/bin/bash' 'if [[ "$1" == "-Qqo" && "$2" == *protected.desktop ]]; then echo fakepkg; exit 0; fi' 'exit 1' > "$DC_FAKEBIN/pacman"
chmod +x "$DC_FAKEBIN/pacman"
export PATH="$DC_FAKEBIN:$DC_BIN:/usr/bin:/bin"
assert_true "unowned valid system entry is kept" "! desktop_cleanup_system_file '$DC_SYSAPPS/valid.desktop'"
assert_true "package-owned entry is kept even with missing exec" "! desktop_cleanup_system_file '$DC_SYSAPPS/protected.desktop'"

export OMACONF_SYSTEM_APPS_DIRS="$DC_SYSAPPS"
desktop_cleanup_sweep
assert_true "unowned system orphan removed" "[[ ! -f '$DC_SYSAPPS/orphan.desktop' ]]"
assert_true "unowned valid system entry kept by the sweep" "[[ -f '$DC_SYSAPPS/valid.desktop' ]]"
assert_true "package-owned entry survives the sweep" "[[ -f '$DC_SYSAPPS/protected.desktop' ]]"
export PATH="$DC_BIN:/usr/bin:/bin"

OMACONF_OMARCHY_APPS_DIR="$DC_SYS" OMACONF_HOMES_ROOT="$DC_HOMES" OMACONF_SYSTEM_APPS_DIRS="$DC_SANDBOX/sysapps" OMACONF_DESKTOP_SKIP_REFRESH=1 bash "$LIB"
assert_true "standalone helper removes tryexec orphans" "[[ ! -f '$DC_HOMES/tester/.local/share/applications/alsogone.desktop' ]]"

printf '#!/bin/bash\nexit 0\n' > "$DC_BIN/baobab"
chmod +x "$DC_BIN/baobab"
export OMACONF_SYSTEM_APPS_DIRS="$DC_SANDBOX/sysapps"
printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Disk analyzer' 'Exec=baobab' > "$DC_SANDBOX/sysapps/org.gnome.baobab.desktop"
printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Duplicate' 'Exec=env GTK_USE_PORTAL=1 /usr/bin/baobab %U' > "$DC_SYS/graphical-disk.desktop"
assert_true "wrapped alias of the canonical analyzer is removed" "desktop_cleanup_file '$DC_SYS/graphical-disk.desktop'"
assert_false "duplicate analyzer entry no longer exists" "[[ -e '$DC_SYS/graphical-disk.desktop' ]]"
assert_false "canonical analyzer entry is preserved" "desktop_cleanup_file '$DC_SANDBOX/sysapps/org.gnome.baobab.desktop'"
printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Duplicate with spaces' 'Exec=baobab' > "$DC_SYS/Another Disk.desktop"
printf '[Default Applications]\napplication/x-test=Another Disk.desktop;keep.desktop;\n[Added Associations]\napplication/x-test=Another Disk.desktop;keep.desktop;\n' > "$DC_HOMES/tester/.config/mimeapps.list"
desktop_cleanup_sweep
assert_file_not_contains "duplicate IDs containing spaces are cleaned exactly" "$DC_HOMES/tester/.config/mimeapps.list" 'Another Disk.desktop'
assert_file_contains_literal "duplicate cleanup preserves unrelated associations" "$DC_HOMES/tester/.config/mimeapps.list" 'application/x-test=keep.desktop;'
rm -f "$DC_SANDBOX/sysapps/org.gnome.baobab.desktop"
printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Only analyzer' 'Exec=baobab' > "$DC_SYS/sole-analyzer.desktop"
assert_false "aliases remain when no canonical entry is available" "desktop_cleanup_file '$DC_SYS/sole-analyzer.desktop'"
printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Disk Usage' 'Hidden=true' > "$DC_HOMES/tester/.local/share/applications/Disk Usage.desktop"
assert_false "hidden legacy aliases survive subsequent cleanup" "desktop_cleanup_file '$DC_HOMES/tester/.local/share/applications/Disk Usage.desktop'"

printf '#!/bin/bash\nexit 0\n' > "$DC_BIN/papers"
chmod +x "$DC_BIN/papers"
printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Papers' 'Exec=papers' > "$DC_SANDBOX/sysapps/org.gnome.Papers.desktop"
printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Protected viewer' 'Exec=papers' > "$DC_SANDBOX/sysapps/protected.desktop"
export PATH="$DC_FAKEBIN:$DC_BIN:/usr/bin:/bin"
assert_true "package-owned duplicate gets a persistent user override" "desktop_cleanup_sweep"
assert_file_exists "package-owned duplicate is not modified" "$DC_SANDBOX/sysapps/protected.desktop"
assert_file_contains_literal "package-owned duplicate is hidden for the user" "$DC_HOMES/tester/.local/share/applications/protected.desktop" 'Hidden=true'
before=$(sha256sum "$DC_HOMES/tester/.local/share/applications/protected.desktop")
assert_true "duplicate overrides survive repeated sweeps" "desktop_cleanup_sweep; [[ \"\$(sha256sum '$DC_HOMES/tester/.local/share/applications/protected.desktop')\" == '$before' ]]"
assert_true "unique launcher verification honors user overrides" "desktop_cleanup_unique '$DC_HOMES/tester'"
rm -f "$DC_HOMES/tester/.local/share/applications/protected.desktop"
assert_false "unique launcher verification catches visible package aliases" "desktop_cleanup_unique '$DC_HOMES/tester'"
mkdir -p "$DC_SANDBOX/cache"
# shellcheck disable=SC2329
update-desktop-database() { printf '[MIME Cache]\n' > "$1/mimeinfo.cache"; chmod 600 "$1/mimeinfo.cache"; }
assert_true "desktop cache refresh succeeds" "_desktop_cleanup_refresh_dir '$DC_SANDBOX/cache'"
assert_true "shared desktop cache remains readable" "[[ \$(stat -c %a '$DC_SANDBOX/cache/mimeinfo.cache') == 644 ]]"
unset -f update-desktop-database

rm -rf "$DC_SANDBOX"

test_summary
