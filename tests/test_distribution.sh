#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
source "$PROJECT_DIR/scripts/lib/distribution.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
ROOT="$SANDBOX/root"
VERSION=$(kos_version "$PROJECT_DIR")
test_section "kos Runtime Distribution"
assert_true "release version is validated" '[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]'
assert_false "staging rejects an inconsistent version" 'kos_package_stage "$PROJECT_DIR" "$ROOT" 99.0.0'
assert_false "invalid staging does not create a runtime" '[[ -e "$ROOT" ]]'
assert_true "runtime staging generates the complete package filesystem" 'kos_package_stage "$PROJECT_DIR" "$ROOT" "$VERSION"'
assert_false "an existing staging root cannot be overwritten" 'kos_package_stage "$PROJECT_DIR" "$ROOT" "$VERSION"'
assert_true "runtime paths and text contain no previous branding" '! rg -q -i "omarchy|omaconf" "$ROOT"'
assert_true "source catalogs remain canonical" 'cmp "$PROJECT_DIR/scripts/lib/messages/it.msg" "$ROOT/usr/share/kos/lib/messages/it.msg"'
assert_true "restrictive build umask cannot hide runtime files from users" '[[ $(stat -c %a "$ROOT/usr/share/kos/lib/release-manifest.sh") == 644 && $(stat -c %a "$ROOT/usr/bin/limine-entry-tool") == 755 && $(stat -c %a "$ROOT/usr/share/kos") == 755 ]]'
assert_true "provisioning does not contain a recursive runtime copy" '[[ ! -e "$ROOT/usr/share/kos/provision/conf/kos/data/rootfs" ]]'
assert_true "private profiles and build outputs are excluded" '[[ ! -e "$ROOT/home" && ! -e "$ROOT/usr/share/kos/provision/dist" && ! -e "$ROOT/usr/share/kos/provision/.git" ]]'
assert_true "palette templates resolve during staging" '[[ -s "$ROOT/etc/skel/.local/state/kos/current/theme/hyprland.lua" ]] && ! rg -q "\{\{" "$ROOT/etc/skel/.local/state/kos/current/theme"'
assert_true "release desktop uses the configured theme" 'cmp "$PROJECT_DIR/conf/kos/data/default-theme" "$ROOT/etc/skel/.local/state/kos/current/theme.name"'
assert_true "original copyright notice remains in the runtime" 'grep -q "Copyright (c) David Heinemeier Hansson" "$ROOT/usr/share/kos/LICENSE"'
assert_true "command metadata has no route collisions" 'KOS_PATH="$ROOT/usr/share/kos" bash "$ROOT/usr/bin/kos" commands --check'
assert_true "kos version reports the release without a package manager lookup" '[[ "$(KOS_PATH="$ROOT/usr/share/kos" bash "$ROOT/usr/bin/kos-version")" == "$VERSION" ]]'
assert_true "all runtime shell commands parse" '(for command in "$ROOT/usr/bin/"*; do read -r interpreter < "$command"; [[ "$interpreter" == *bash* ]] || continue; bash -n "$command" || exit 1; done)'
cat > "$ROOT/usr/bin/kos-launch-test-driver" <<'MOCK'
#!/usr/bin/env bash
# kos:summary=Forward command arguments
printf '%s\n' "$@" > "$DISPATCH_OUTPUT"
MOCK
chmod 755 "$ROOT/usr/bin/kos-launch-test-driver"
export DISPATCH_OUTPUT="$SANDBOX/dispatch"
assert_true "dispatcher forwards argument boundaries without evaluation" 'KOS_PATH="$ROOT/usr/share/kos" bash "$ROOT/usr/bin/kos" launch test driver "space argument" '\''$(touch forbidden)'\'' && [[ "$(sed -n 1p "$DISPATCH_OUTPUT")" == "space argument" && "$(sed -n 2p "$DISPATCH_OUTPUT")" == '\''$(touch forbidden)'\'' && ! -e forbidden ]]'
assert_false "unknown commands return failure" 'KOS_PATH="$ROOT/usr/share/kos" bash "$ROOT/usr/bin/kos" nonexistent action'
assert_true "command help never executes destructive refreshes" 'KOS_PATH="$ROOT/usr/share/kos" bash "$ROOT/usr/bin/kos" refresh pacman --help'
test_summary
