#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
UPDATE_SANDBOX=$(mktemp -d)
trap 'rm -rf "$UPDATE_SANDBOX"' EXIT
mkdir -p "$UPDATE_SANDBOX"/{bin,trusted,hooks/post-update.d,hooks/i18n,hooks/lib,homes,run/user/1234}
cp "$PROJECT_DIR/scripts/lib/i18n.sh" "$UPDATE_SANDBOX/trusted/"
cp -r "$PROJECT_DIR/scripts/lib/messages" "$UPDATE_SANDBOX/trusted/"
cp "$PROJECT_DIR/scripts/lib/i18n-boot.sh" "$PROJECT_DIR/scripts/lib/i18n.sh" "$UPDATE_SANDBOX/hooks/i18n/"
cp -r "$PROJECT_DIR/scripts/lib/messages" "$UPDATE_SANDBOX/hooks/i18n/"
sed -e 's/\$EUID/${HOOK_TEST_EUID}/g' \
    -e "s|/usr/local/lib/kos|$UPDATE_SANDBOX/trusted|g" \
    -e "s|/usr/local/libexec/kos-desktop-cleanup|$UPDATE_SANDBOX/bin/cleanup|g" \
    -e "s|/home/\*|$UPDATE_SANDBOX/homes/*|g" \
    -e "s|/run/user/|$UPDATE_SANDBOX/run/user/|g" \
    "$PROJECT_DIR/hooks/post-update.d/99-kos-persist" > "$UPDATE_SANDBOX/hooks/post-update.d/99-kos-persist"
cat > "$UPDATE_SANDBOX/bin/id" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
    -un) printf 'testuser\n' ;;
    -u) printf '1234\n' ;;
    *) exit 1 ;;
esac
MOCK
cat > "$UPDATE_SANDBOX/bin/getent" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s:x:1234:1234::%s:/bin/bash\n' "$2" "$HOME"
MOCK
cat > "$UPDATE_SANDBOX/bin/sudo" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo %s\n' "$*" >> "$UPDATE_COMMANDS"
shift 2
exec "$@"
MOCK
cat > "$UPDATE_SANDBOX/bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'systemctl %s\n' "$*" >> "$UPDATE_COMMANDS"
MOCK
cat > "$UPDATE_SANDBOX/bin/gsettings" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'cursor %s %s %s\n' "$HOME" "$XDG_RUNTIME_DIR" "$DBUS_SESSION_BUS_ADDRESS" >> "$UPDATE_COMMANDS"
MOCK
cat > "$UPDATE_SANDBOX/bin/cleanup" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'cleanup\n' >> "$UPDATE_COMMANDS"
MOCK
cat > "$UPDATE_SANDBOX/hooks/lib/desktop-workflow.sh" <<'MOCK'
desktop_workflow_defaults() {
    printf 'defaults %s %s\n' "$1" "$2" >> "$UPDATE_COMMANDS"
    [[ ${UPDATE_DEFAULTS_FAIL:-0} == 0 ]]
}
desktop_workflow_portals() {
    printf 'portals %s %s\n' "$1" "$2" >> "$UPDATE_COMMANDS"
}
MOCK
cp "$UPDATE_SANDBOX/hooks/lib/desktop-workflow.sh" "$UPDATE_SANDBOX/trusted/"
cat > "$UPDATE_SANDBOX/hooks/lib/theme-preview.sh" <<'MOCK'
theme_preview_normalize() {
    printf 'previews\n' >> "$UPDATE_COMMANDS"
    [[ ${UPDATE_PREVIEW_FAIL:-0} == 0 ]]
}
MOCK
cp "$UPDATE_SANDBOX/hooks/lib/theme-preview.sh" "$UPDATE_SANDBOX/trusted/"
cat > "$UPDATE_SANDBOX/trusted/os-identity.sh" <<'MOCK'
kos_identity_apply() {
    printf 'identity\n' >> "$UPDATE_COMMANDS"
}
MOCK
printf 'printf "untrusted\\n" >> "$UPDATE_COMMANDS"\nexit 97\n' > "$UPDATE_SANDBOX/untrusted.sh"
for update_home in "$UPDATE_SANDBOX/own home" "$UPDATE_SANDBOX/homes/otheruser"; do
    mkdir -p "$update_home/.config/kos/hooks/theme-set.d"
    for update_hook in folder-color gtk-theme shell-icons; do
        cat > "$update_home/.config/kos/hooks/theme-set.d/$update_hook" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'theme %s %s %s\n' "$HOME" "$XDG_RUNTIME_DIR" "$DBUS_SESSION_BUS_ADDRESS" >> "$UPDATE_COMMANDS"
MOCK
    done
done
touch "$UPDATE_SANDBOX/run/user/1234/bus"
chmod 755 "$UPDATE_SANDBOX/bin/"*
export UPDATE_COMMANDS="$UPDATE_SANDBOX/commands"

run_update_hook() {
    env PATH="$UPDATE_SANDBOX/bin:$PATH" HOME="$UPDATE_SANDBOX/own home" \
        HOOK_TEST_EUID="$1" KOS_LANG=en KOS_RELEASE_VERSION=0.1.0 \
        bash "$UPDATE_SANDBOX/hooks/post-update.d/99-kos-persist" \
        > "$UPDATE_SANDBOX/stdout" 2> "$UPDATE_SANDBOX/stderr"
}

test_section "Update Hook Privilege Boundaries"
assert_true "pre-refresh succeeds without loading arbitrary bootstrap code" \
    "KOS_I18N_BOOT='$UPDATE_SANDBOX/untrusted.sh' bash '$PROJECT_DIR/hooks/pre-refresh-pacman.d/99-kos-persist'"
assert_true "user update hook completes with an isolated home" "run_update_hook 1000"
assert_file_contains_literal "user hook uses the account name rather than the home basename" "$UPDATE_COMMANDS" "defaults testuser $UPDATE_SANDBOX/own home"
assert_file_not_contains "user update does not touch other homes" "$UPDATE_COMMANDS" 'otheruser'
assert_file_not_contains "user update never escalates privileges" "$UPDATE_COMMANDS" '^sudo '
assert_file_not_contains "user update skips privileged cleanup and previews" "$UPDATE_COMMANDS" '^(cleanup|previews|identity)$'
assert_file_contains_literal "cursor receives the user home and session bus" "$UPDATE_COMMANDS" "cursor $UPDATE_SANDBOX/own home $UPDATE_SANDBOX/run/user/1234 unix:path=$UPDATE_SANDBOX/run/user/1234/bus"
assert_equal "all palette hooks run in the user session" "$(grep -c '^theme ' "$UPDATE_COMMANDS")" 3
cp "$UPDATE_COMMANDS" "$UPDATE_SANDBOX/first-run"
: > "$UPDATE_COMMANDS"
assert_true "repeated update succeeds" "run_update_hook 1000"
assert_true "repeated update dispatches the same reconciliation" "cmp -s '$UPDATE_COMMANDS' '$UPDATE_SANDBOX/first-run'"
export UPDATE_DEFAULTS_FAIL=1
assert_true "optional desktop failure does not block package updates" "run_update_hook 1000"
assert_file_contains "optional desktop failure emits a diagnostic" "$UPDATE_SANDBOX/stderr" 'Warning:'
unset UPDATE_DEFAULTS_FAIL

: > "$UPDATE_COMMANDS"
export KOS_I18N_BOOT="$UPDATE_SANDBOX/untrusted.sh" \
    KOS_DESKTOP_WORKFLOW="$UPDATE_SANDBOX/untrusted.sh" \
    KOS_THEME_PREVIEW="$UPDATE_SANDBOX/untrusted.sh" \
    KOS_I18N_DIR="$UPDATE_SANDBOX/untrusted"
assert_true "root update ignores user supplied library overrides" "run_update_hook 0"
assert_file_not_contains "root never executes overridden user libraries" "$UPDATE_COMMANDS" '^untrusted$'
assert_file_contains "root uses the privileged preview library" "$UPDATE_COMMANDS" '^previews$'
assert_file_contains "root uses privileged identity reconciliation" "$UPDATE_COMMANDS" '^identity$'
export UPDATE_PREVIEW_FAIL=1
assert_false "required privileged reconciliation propagates failure" "run_update_hook 0"
unset UPDATE_PREVIEW_FAIL
mv "$UPDATE_SANDBOX/trusted/desktop-workflow.sh" "$UPDATE_SANDBOX/trusted/desktop-workflow.saved"
assert_false "missing privileged library fails rather than sourcing a user library" "run_update_hook 0"
assert_file_not_contains "missing privileged library does not execute user override" "$UPDATE_COMMANDS" '^untrusted$'

mkdir -p "$UPDATE_SANDBOX/install-homes/$(id -un)"
awk '/^if .*KOS_REBUILD_PREVIEWS/ { exit } /^log "theming.hooks"$/ { found=1 } found { print }' \
    "$PROJECT_DIR/scripts/lib/modules/30-theming.sh" | \
    sed "s|/home/\\*|$UPDATE_SANDBOX/install-homes/*|g" > "$UPDATE_SANDBOX/install-hooks.sh"
install_hooks_with_dependencies() (
    PATH=/usr/bin:/bin
    # shellcheck disable=SC2329
    log() { printf '%s\n' "$*"; }
    # shellcheck disable=SC2329
    warn() { return 1; }
    # shellcheck disable=SC2329
    user_as() {
        local hook_root
        hook_root=$(dirname "$(dirname "$3")")
        [[ -r "$hook_root/i18n/i18n-boot.sh" && -r "$hook_root/i18n/messages/en.msg" &&
            -r "$hook_root/lib/desktop-workflow.sh" && -r "$hook_root/lib/portals.conf" ]]
    }
    source "$UPDATE_SANDBOX/install-hooks.sh"
)
assert_true "fresh hook installation stages all dependencies before invoking hooks" "install_hooks_with_dependencies"

test_summary
