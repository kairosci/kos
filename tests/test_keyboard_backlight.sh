#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
KEYBOARD_SANDBOX=$(mktemp -d)
trap 'rm -rf "$KEYBOARD_SANDBOX"' EXIT
export OS_KEYBOARD_LEDS_ROOT="$KEYBOARD_SANDBOX/leds" OS_LANG=en
export OS_I18N_BOOT="$PROJECT_DIR/scripts/lib/i18n.sh"
mkdir -p "$OS_KEYBOARD_LEDS_ROOT"/{vendor::kbd_backlight,other::kbd_backlight,input::capslock} "$KEYBOARD_SANDBOX/bin"
printf '3\n' > "$OS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/max_brightness"
printf '0\n' > "$OS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/brightness"
printf '255\n' > "$OS_KEYBOARD_LEDS_ROOT/other::kbd_backlight/max_brightness"
printf '1\n' > "$OS_KEYBOARD_LEDS_ROOT/other::kbd_backlight/brightness"
printf '0\n' > "$OS_KEYBOARD_LEDS_ROOT/input::capslock/brightness"
cat > "$KEYBOARD_SANDBOX/bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == 'is-active --quiet sleep.target' ]]; then
    exit "${KEYBOARD_SLEEP_STATUS:-3}"
fi
[[ -n "${KEYBOARD_COMMANDS:-}" ]] || exit 9
case "$*" in
    daemon-reload|'enable os-keyboard-backlight.service'|'restart os-keyboard-backlight.service'|'enable --now os-keyboard-backlight.timer') ;;
    *) exit 9 ;;
esac
printf '%s\n' "$*" >> "$KEYBOARD_COMMANDS"
[[ "${KEYBOARD_CONTROL_FAIL:-0}" == 0 ]]
MOCK
chmod 755 "$KEYBOARD_SANDBOX/bin/systemctl"
export PATH="$KEYBOARD_SANDBOX/bin:$PATH"
KEYBOARD_HELPER="$PROJECT_DIR/scripts/lib/keyboard-backlight.sh"

test_section "Maximum keyboard backlight"
assert_false "read-only check detects dimmed keyboards" "bash '$KEYBOARD_HELPER' --check"
assert_true "helper applies each device maximum" "bash '$KEYBOARD_HELPER'"
assert_equal "three-level keyboard reaches maximum" "$(cat "$OS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/brightness")" 3
assert_equal "high-resolution keyboard reaches its own maximum" "$(cat "$OS_KEYBOARD_LEDS_ROOT/other::kbd_backlight/brightness")" 255
assert_equal "lock indicator remains untouched" "$(cat "$OS_KEYBOARD_LEDS_ROOT/input::capslock/brightness")" 0
assert_true "read-only check accepts maximum brightness" "bash '$KEYBOARD_HELPER' --check"
first_hash=$(sha256sum "$OS_KEYBOARD_LEDS_ROOT/"*/brightness)
assert_true "reconciliation is idempotent" "bash '$KEYBOARD_HELPER'; [[ \"\$first_hash\" == \"\$(sha256sum '$OS_KEYBOARD_LEDS_ROOT/'*/brightness)\" ]]"
printf '0\n' > "$OS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/brightness"
assert_true "timer skips writes while the system sleeps" "KEYBOARD_SLEEP_STATUS=0 bash '$KEYBOARD_HELPER' --awake"
assert_equal "sleep keeps the keyboard off" "$(cat "$OS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/brightness")" 0
assert_true "awake reconciliation restores the maximum" "bash '$KEYBOARD_HELPER' --awake"
assert_false "session state inspection failure is propagated" "KEYBOARD_SLEEP_STATUS=1 bash '$KEYBOARD_HELPER' --awake"
assert_false "invalid arguments fail visibly" "bash '$KEYBOARD_HELPER' invalid"
assert_false "extra arguments are rejected even during sleep" "KEYBOARD_SLEEP_STATUS=0 bash '$KEYBOARD_HELPER' --awake extra"
printf 'invalid\n' > "$OS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/max_brightness"
assert_false "invalid hardware values are rejected" "bash '$KEYBOARD_HELPER'"
printf '0\n' > "$OS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/max_brightness"
assert_false "zero maximum is not reported as supported" "bash '$KEYBOARD_HELPER'"
rm "$OS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/max_brightness"
assert_false "missing hardware control propagates failure" "bash '$KEYBOARD_HELPER'"
assert_true "absent keyboard backlight is explicitly reported" "OS_KEYBOARD_LEDS_ROOT='$KEYBOARD_SANDBOX/absent' bash '$KEYBOARD_HELPER' > '$KEYBOARD_SANDBOX/unsupported'; grep -q 'No keyboard backlight interface' '$KEYBOARD_SANDBOX/unsupported'"
sed "s|/usr/local/libexec/os-keyboard-backlight|$KEYBOARD_SANDBOX/resume-command|" \
    "$PROJECT_DIR/scripts/lib/keyboard-backlight-resume.sh" > "$KEYBOARD_SANDBOX/resume.sh"
printf '#!/bin/bash\nprintf "restored\\n" > "%s"\n' "$KEYBOARD_SANDBOX/resumed" > "$KEYBOARD_SANDBOX/resume-command"
chmod 755 "$KEYBOARD_SANDBOX/resume-command"
assert_true "pre-sleep preserves upstream keyboard shutdown" "bash '$KEYBOARD_SANDBOX/resume.sh' pre hibernate; [[ ! -e '$KEYBOARD_SANDBOX/resumed' ]]"
assert_true "post-sleep reapplies keyboard brightness" "bash '$KEYBOARD_SANDBOX/resume.sh' post hibernate; [[ -f '$KEYBOARD_SANDBOX/resumed' ]]"
printf '#!/bin/bash\nexit 1\n' > "$KEYBOARD_SANDBOX/resume-command"
assert_false "resume errors propagate" "bash '$KEYBOARD_SANDBOX/resume.sh' post suspend"
printf '3\n' > "$OS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/max_brightness"
cat > "$KEYBOARD_SANDBOX/bin/cat" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "$OS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/brightness" ]]; then
    printf '0\n'
else
    exec /usr/bin/cat "$@"
fi
MOCK
chmod 755 "$KEYBOARD_SANDBOX/bin/cat"
assert_false "hardware read-back rejection is never reported as success" "bash '$KEYBOARD_HELPER'"
rm "$KEYBOARD_SANDBOX/bin/cat"
mkdir -p "$KEYBOARD_SANDBOX/root/etc/udev/rules.d" "$KEYBOARD_SANDBOX/root/etc/systemd/system"
export KEYBOARD_COMMANDS="$KEYBOARD_SANDBOX/commands"
cat > "$KEYBOARD_SANDBOX/bin/udevadm" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == 'control --reload-rules' ]]
printf 'udev %s\n' "$*" >> "$KEYBOARD_COMMANDS"
MOCK
chmod 755 "$KEYBOARD_SANDBOX/bin/udevadm"
printf '%s\n' '#!/bin/bash' 'set -euo pipefail' 'source "$OS_I18N_BOOT"' 'locale_init' > "$KEYBOARD_SANDBOX/provision.sh"
sed '1,2d' "$PROJECT_DIR/scripts/lib/keyboard-backlight-policy.sh" | \
    sed -e "s|/usr/local/libexec/|$KEYBOARD_SANDBOX/root/usr/local/libexec/|g" \
        -e "s|/usr/local/lib/os/|$KEYBOARD_SANDBOX/root/usr/local/lib/os/|g" \
        -e 's/ -o root -g root//g' \
        -e "s|/usr/lib/systemd/system-sleep/|$KEYBOARD_SANDBOX/root/usr/lib/systemd/system-sleep/|g" \
        -e "s|/etc/|$KEYBOARD_SANDBOX/root/etc/|g" >> "$KEYBOARD_SANDBOX/provision.sh"
assert_true "setup installs keyboard boot and device services in an isolated root" "PROJECT_ROOT='$PROJECT_DIR' bash '$KEYBOARD_SANDBOX/provision.sh'"
assert_file_contains_literal "device events queue systemd work instead of blocking udev" "$KEYBOARD_SANDBOX/root/etc/udev/rules.d/99-os-keyboard-backlight.rules" 'ENV{SYSTEMD_WANTS}+="os-keyboard-backlight@$name.service"'
DEVICE_UNIT="$KEYBOARD_SANDBOX/root/etc/systemd/system/os-keyboard-backlight@.service"
assert_true "device unit is ordered after the native brightness restore" "instance='samsung-galaxybook::kbd_backlight'; expected=\"systemd-backlight@leds:\$instance.service\"; resolved=\$(sed \"s/%i/\$instance/g\" '$DEVICE_UNIT'); grep -qxF \"Wants=\$expected\" <<< \"\$resolved\" && grep -qxF \"After=\$expected\" <<< \"\$resolved\""
assert_true "setup installs and enables early boot reconciliation" "grep -qxF 'enable os-keyboard-backlight.service' '$KEYBOARD_COMMANDS' && cmp '$PROJECT_DIR/modules/conf/power/data/os-keyboard-backlight@.service' '$DEVICE_UNIT'"
boot_hash=$(sha256sum "$KEYBOARD_SANDBOX/root/etc/systemd/system/"* "$KEYBOARD_SANDBOX/root/etc/udev/rules.d/"*)
assert_true "repeated keyboard setup produces identical units" "PROJECT_ROOT='$PROJECT_DIR' bash '$KEYBOARD_SANDBOX/provision.sh'; [[ \"\$boot_hash\" == \"\$(sha256sum '$KEYBOARD_SANDBOX/root/etc/systemd/system/'* '$KEYBOARD_SANDBOX/root/etc/udev/rules.d/'*)\" ]]"
assert_false "failed systemd reconciliation stops keyboard setup" "KEYBOARD_CONTROL_FAIL=1 PROJECT_ROOT='$PROJECT_DIR' bash '$KEYBOARD_SANDBOX/provision.sh'"
printf '0\n' > "$OS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/brightness"
keyboard_runtime="$KEYBOARD_SANDBOX/root/usr/local/lib/os"
assert_true "scoped policy installs its trusted message runtime" "cmp '$PROJECT_DIR/scripts/lib/i18n.sh' '$keyboard_runtime/i18n.sh' && cmp '$PROJECT_DIR/scripts/lib/messages/en.msg' '$keyboard_runtime/messages/en.msg'"
sed -e "s|/usr/local/lib/os|$keyboard_runtime|g" -e 's/\$EUID/0/g' \
    "$KEYBOARD_HELPER" > "$KEYBOARD_SANDBOX/root/usr/local/libexec/os-keyboard-backlight"
assert_true "device activation restores a level overwritten by native boot restore" "command=\$(sed -n 's/^ExecStart=//p' '$DEVICE_UNIT'); command=\${command/\/usr\/local\/libexec\/os-keyboard-backlight/\$KEYBOARD_SANDBOX\/root\/usr\/local\/libexec\/os-keyboard-backlight}; bash -c \"\$command\" && [[ \"\$(cat '$OS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/brightness')\" == 3 ]]"
sed -e 's/\$EUID/${KEYBOARD_TEST_EUID}/g' -e "s|/usr/local/lib/os|$keyboard_runtime|g" "$KEYBOARD_HELPER" > "$KEYBOARD_SANDBOX/keyboard-root.sh"
cp "$PROJECT_DIR/scripts/lib/i18n.sh" "$KEYBOARD_SANDBOX/"
cp -r "$PROJECT_DIR/scripts/lib/messages" "$KEYBOARD_SANDBOX/"
printf 'touch "%s"\nexit 93\n' "$KEYBOARD_SANDBOX/untrusted-ran" > "$KEYBOARD_SANDBOX/untrusted.sh"
assert_true "root keyboard checks ignore user supplied bootstrap code" "KEYBOARD_TEST_EUID=0 OS_I18N_BOOT='$KEYBOARD_SANDBOX/untrusted.sh' bash '$KEYBOARD_SANDBOX/keyboard-root.sh' --check && [[ ! -e '$KEYBOARD_SANDBOX/untrusted-ran' ]]"
SETUP_PROJECT="$KEYBOARD_SANDBOX/setup-project"
mkdir -p "$SETUP_PROJECT/scripts/lib/modules" "$SETUP_PROJECT/bin" "$SETUP_PROJECT/omarchy"
cp "$PROJECT_DIR/scripts/lib/i18n.sh" "$SETUP_PROJECT/scripts/lib/"
printf '%s\n' 'root_setup_persistent() { return 0; }' > "$SETUP_PROJECT/scripts/lib/root-recovery.sh"
cp -r "$PROJECT_DIR/scripts/lib/messages" "$SETUP_PROJECT/scripts/lib/"
sed -e 's/\$EUID/${SETUP_TEST_EUID}/g' -e "s|/usr/share/omarchy|$SETUP_PROJECT/omarchy|g" "$PROJECT_DIR/scripts/setup.sh" > "$SETUP_PROJECT/scripts/setup.sh"
cat > "$SETUP_PROJECT/scripts/lib/target-user.sh" <<'MOCK'
target_user_resolve() {
    printf 'target\n' >> "$SETUP_TRACE"
    printf 'setup-user\n'
}
MOCK
cat > "$SETUP_PROJECT/bin/id" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == setup-user ]]
MOCK
cat > "$SETUP_PROJECT/bin/pacman" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == '-Q omarchy' && ${SETUP_NATIVE_MISSING:-0} == 0 ]]
MOCK
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'exit 0' > "$SETUP_PROJECT/bin/omarchy"
chmod 755 "$SETUP_PROJECT/bin/"*
printf '%s\n' 'printf "keyboard\n" >> "$SETUP_TRACE"' > "$SETUP_PROJECT/scripts/lib/keyboard-backlight-policy.sh"
printf '%s\n' 'printf "packages\n" >> "$SETUP_TRACE"' > "$SETUP_PROJECT/scripts/lib/modules/00-env.sh"
while IFS= read -r module; do
    [[ -f "$SETUP_PROJECT/scripts/lib/modules/$module" ]] || printf 'return 0\n' > "$SETUP_PROJECT/scripts/lib/modules/$module"
done < <(sed -n 's|^[[:space:]]*"\$MODULES_DIR/\([^"]*\)".*|\1|p' "$PROJECT_DIR/scripts/setup.sh")
printf '%s\n' 'source "$PROJECT_ROOT/scripts/lib/keyboard-backlight-policy.sh"' > "$SETUP_PROJECT/scripts/lib/modules/91-suspend-resume.sh"
SETUP_TRACE="$KEYBOARD_SANDBOX/setup-trace"
run_setup_scope() {
    PATH="$SETUP_PROJECT/bin:$PATH" SETUP_TEST_EUID="${SETUP_TEST_EUID:-0}" OS_LOG_STDOUT=1 SETUP_TRACE="$SETUP_TRACE" \
        OS_I18N_DIR="$SETUP_PROJECT/scripts/lib/messages" bash "$SETUP_PROJECT/scripts/setup.sh" "$@"
}
: > "$SETUP_TRACE"
assert_true "keyboard setup scope runs without resolving an unrelated desktop user" "run_setup_scope --scope keyboard && [[ \"\$(cat '$SETUP_TRACE')\" == keyboard ]]"
: > "$SETUP_TRACE"
assert_false "unknown scope cannot fall through to a full system upgrade" "run_setup_scope --scope invalid"
assert_false "missing setup scope value is rejected" "run_setup_scope --scope"
assert_false "duplicate setup scopes are rejected" "run_setup_scope --scope keyboard --scope full"
assert_false "keyboard scope refuses desktop preview regeneration" "run_setup_scope --scope keyboard --rebuild-previews"
assert_false "keyboard scope rejects inherited preview regeneration" "OS_REBUILD_PREVIEWS=1 run_setup_scope --scope keyboard"
assert_false "keyboard scope retains the privileged setup requirement" "SETUP_TEST_EUID=1000 run_setup_scope --scope keyboard"
assert_true "invalid and unprivileged scopes leave all stages untouched" "[[ ! -s '$SETUP_TRACE' ]]"
assert_true "default setup still runs the full module list" "run_setup_scope && [[ \"\$(cat '$SETUP_TRACE')\" == $'target\npackages\nkeyboard' ]]"
: > "$SETUP_TRACE"
assert_false "full setup rejects a missing native Omarchy package" "SETUP_NATIVE_MISSING=1 run_setup_scope"
assert_true "missing native runtime stops before package provisioning" "[[ \"\$(cat '$SETUP_TRACE')\" == target ]]"

test_summary
