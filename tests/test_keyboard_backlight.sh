#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
KEYBOARD_SANDBOX=$(mktemp -d)
trap 'rm -rf "$KEYBOARD_SANDBOX"' EXIT
export KOS_KEYBOARD_LEDS_ROOT="$KEYBOARD_SANDBOX/leds" KOS_LANG=en
export KOS_I18N_BOOT="$PROJECT_DIR/scripts/lib/i18n.sh"
mkdir -p "$KOS_KEYBOARD_LEDS_ROOT"/{vendor::kbd_backlight,other::kbd_backlight,input::capslock} "$KEYBOARD_SANDBOX/bin"
printf '3\n' > "$KOS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/max_brightness"
printf '0\n' > "$KOS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/brightness"
printf '255\n' > "$KOS_KEYBOARD_LEDS_ROOT/other::kbd_backlight/max_brightness"
printf '1\n' > "$KOS_KEYBOARD_LEDS_ROOT/other::kbd_backlight/brightness"
printf '0\n' > "$KOS_KEYBOARD_LEDS_ROOT/input::capslock/brightness"
cat > "$KEYBOARD_SANDBOX/bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == 'is-active --quiet sleep.target' ]]; then
    exit "${KEYBOARD_SLEEP_STATUS:-3}"
fi
[[ -n "${KEYBOARD_COMMANDS:-}" ]] || exit 9
case "$*" in
    daemon-reload|'enable kos-keyboard-backlight.service'|'restart kos-keyboard-backlight.service'|'enable --now kos-keyboard-backlight.timer') ;;
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
assert_equal "three-level keyboard reaches maximum" "$(cat "$KOS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/brightness")" 3
assert_equal "high-resolution keyboard reaches its own maximum" "$(cat "$KOS_KEYBOARD_LEDS_ROOT/other::kbd_backlight/brightness")" 255
assert_equal "lock indicator remains untouched" "$(cat "$KOS_KEYBOARD_LEDS_ROOT/input::capslock/brightness")" 0
assert_true "read-only check accepts maximum brightness" "bash '$KEYBOARD_HELPER' --check"
first_hash=$(sha256sum "$KOS_KEYBOARD_LEDS_ROOT/"*/brightness)
assert_true "reconciliation is idempotent" "bash '$KEYBOARD_HELPER'; [[ \"\$first_hash\" == \"\$(sha256sum '$KOS_KEYBOARD_LEDS_ROOT/'*/brightness)\" ]]"
printf '0\n' > "$KOS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/brightness"
assert_true "timer skips writes while the system sleeps" "KEYBOARD_SLEEP_STATUS=0 bash '$KEYBOARD_HELPER' --awake"
assert_equal "sleep keeps the keyboard off" "$(cat "$KOS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/brightness")" 0
assert_true "awake reconciliation restores the maximum" "bash '$KEYBOARD_HELPER' --awake"
assert_false "session state inspection failure is propagated" "KEYBOARD_SLEEP_STATUS=1 bash '$KEYBOARD_HELPER' --awake"
assert_false "invalid arguments fail visibly" "bash '$KEYBOARD_HELPER' invalid"
assert_false "extra arguments are rejected even during sleep" "KEYBOARD_SLEEP_STATUS=0 bash '$KEYBOARD_HELPER' --awake extra"
printf 'invalid\n' > "$KOS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/max_brightness"
assert_false "invalid hardware values are rejected" "bash '$KEYBOARD_HELPER'"
printf '0\n' > "$KOS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/max_brightness"
assert_false "zero maximum is not reported as supported" "bash '$KEYBOARD_HELPER'"
rm "$KOS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/max_brightness"
assert_false "missing hardware control propagates failure" "bash '$KEYBOARD_HELPER'"
assert_true "absent keyboard backlight is explicitly reported" "KOS_KEYBOARD_LEDS_ROOT='$KEYBOARD_SANDBOX/absent' bash '$KEYBOARD_HELPER' > '$KEYBOARD_SANDBOX/unsupported'; grep -q 'No keyboard backlight interface' '$KEYBOARD_SANDBOX/unsupported'"
sed "s|/usr/local/libexec/kos-keyboard-backlight|$KEYBOARD_SANDBOX/resume-command|" \
    "$PROJECT_DIR/scripts/lib/keyboard-backlight-resume.sh" > "$KEYBOARD_SANDBOX/resume.sh"
printf '#!/bin/bash\nprintf "restored\\n" > "%s"\n' "$KEYBOARD_SANDBOX/resumed" > "$KEYBOARD_SANDBOX/resume-command"
chmod 755 "$KEYBOARD_SANDBOX/resume-command"
assert_true "pre-sleep preserves upstream keyboard shutdown" "bash '$KEYBOARD_SANDBOX/resume.sh' pre hibernate; [[ ! -e '$KEYBOARD_SANDBOX/resumed' ]]"
assert_true "post-sleep reapplies keyboard brightness" "bash '$KEYBOARD_SANDBOX/resume.sh' post hibernate; [[ -f '$KEYBOARD_SANDBOX/resumed' ]]"
printf '#!/bin/bash\nexit 1\n' > "$KEYBOARD_SANDBOX/resume-command"
assert_false "resume errors propagate" "bash '$KEYBOARD_SANDBOX/resume.sh' post suspend"
printf '3\n' > "$KOS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/max_brightness"
cat > "$KEYBOARD_SANDBOX/bin/cat" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "$KOS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/brightness" ]]; then
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
printf '%s\n' '#!/bin/bash' 'set -euo pipefail' 'source "$KOS_I18N_BOOT"' 'i18n_init' > "$KEYBOARD_SANDBOX/provision.sh"
sed '1,2d' "$PROJECT_DIR/scripts/lib/keyboard-backlight-policy.sh" | \
    sed -e "s|/usr/local/libexec/|$KEYBOARD_SANDBOX/root/usr/local/libexec/|g" \
        -e "s|/usr/local/lib/kos/|$KEYBOARD_SANDBOX/root/usr/local/lib/kos/|g" \
        -e 's/ -o root -g root//g' \
        -e "s|/usr/lib/systemd/system-sleep/|$KEYBOARD_SANDBOX/root/usr/lib/systemd/system-sleep/|g" \
        -e "s|/etc/|$KEYBOARD_SANDBOX/root/etc/|g" >> "$KEYBOARD_SANDBOX/provision.sh"
assert_true "setup installs keyboard boot and device services in an isolated root" "PROJECT_ROOT='$PROJECT_DIR' bash '$KEYBOARD_SANDBOX/provision.sh'"
assert_file_contains_literal "device events queue systemd work instead of blocking udev" "$KEYBOARD_SANDBOX/root/etc/udev/rules.d/99-kos-keyboard-backlight.rules" 'ENV{SYSTEMD_WANTS}+="kos-keyboard-backlight@$name.service"'
DEVICE_UNIT="$KEYBOARD_SANDBOX/root/etc/systemd/system/kos-keyboard-backlight@.service"
assert_true "device unit is ordered after the native brightness restore" "instance='samsung-galaxybook::kbd_backlight'; expected=\"systemd-backlight@leds:\$instance.service\"; resolved=\$(sed \"s/%i/\$instance/g\" '$DEVICE_UNIT'); grep -qxF \"Wants=\$expected\" <<< \"\$resolved\" && grep -qxF \"After=\$expected\" <<< \"\$resolved\""
assert_true "setup installs and enables early boot reconciliation" "grep -qxF 'enable kos-keyboard-backlight.service' '$KEYBOARD_COMMANDS' && cmp '$PROJECT_DIR/conf/power/data/kos-keyboard-backlight@.service' '$DEVICE_UNIT'"
boot_hash=$(sha256sum "$KEYBOARD_SANDBOX/root/etc/systemd/system/"* "$KEYBOARD_SANDBOX/root/etc/udev/rules.d/"*)
assert_true "repeated keyboard setup produces identical units" "PROJECT_ROOT='$PROJECT_DIR' bash '$KEYBOARD_SANDBOX/provision.sh'; [[ \"\$boot_hash\" == \"\$(sha256sum '$KEYBOARD_SANDBOX/root/etc/systemd/system/'* '$KEYBOARD_SANDBOX/root/etc/udev/rules.d/'*)\" ]]"
assert_false "failed systemd reconciliation stops keyboard setup" "KEYBOARD_CONTROL_FAIL=1 PROJECT_ROOT='$PROJECT_DIR' bash '$KEYBOARD_SANDBOX/provision.sh'"
printf '0\n' > "$KOS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/brightness"
keyboard_runtime="$KEYBOARD_SANDBOX/root/usr/local/lib/kos"
assert_true "scoped policy installs its trusted message runtime" "cmp '$PROJECT_DIR/scripts/lib/i18n.sh' '$keyboard_runtime/i18n.sh' && cmp '$PROJECT_DIR/scripts/lib/messages/en.msg' '$keyboard_runtime/messages/en.msg'"
sed -e "s|/usr/local/lib/kos|$keyboard_runtime|g" -e 's/\$EUID/0/g' \
    "$KEYBOARD_HELPER" > "$KEYBOARD_SANDBOX/root/usr/local/libexec/kos-keyboard-backlight"
assert_true "device activation restores a level overwritten by native boot restore" "command=\$(sed -n 's/^ExecStart=//p' '$DEVICE_UNIT'); command=\${command/\/usr\/local\/libexec\/kos-keyboard-backlight/\$KEYBOARD_SANDBOX\/root\/usr\/local\/libexec\/kos-keyboard-backlight}; bash -c \"\$command\" && [[ \"\$(cat '$KOS_KEYBOARD_LEDS_ROOT/vendor::kbd_backlight/brightness')\" == 3 ]]"
sed 's/\$EUID/${KEYBOARD_TEST_EUID}/g' "$KEYBOARD_HELPER" > "$KEYBOARD_SANDBOX/keyboard-root.sh"
cp "$PROJECT_DIR/scripts/lib/i18n.sh" "$KEYBOARD_SANDBOX/"
cp -r "$PROJECT_DIR/scripts/lib/messages" "$KEYBOARD_SANDBOX/"
printf 'touch "%s"\nexit 93\n' "$KEYBOARD_SANDBOX/untrusted-ran" > "$KEYBOARD_SANDBOX/untrusted.sh"
assert_true "root keyboard checks ignore user supplied bootstrap code" "KEYBOARD_TEST_EUID=0 KOS_I18N_BOOT='$KEYBOARD_SANDBOX/untrusted.sh' bash '$KEYBOARD_SANDBOX/keyboard-root.sh' --check && [[ ! -e '$KEYBOARD_SANDBOX/untrusted-ran' ]]"
SETUP_PROJECT="$KEYBOARD_SANDBOX/setup-project"
mkdir -p "$SETUP_PROJECT/scripts/lib/modules"
cp "$PROJECT_DIR/scripts/lib/i18n.sh" "$SETUP_PROJECT/scripts/lib/"
cp -r "$PROJECT_DIR/scripts/lib/messages" "$SETUP_PROJECT/scripts/lib/"
sed 's/\$EUID/${SETUP_TEST_EUID}/g' "$PROJECT_DIR/scripts/setup.sh" > "$SETUP_PROJECT/scripts/setup.sh"
cat > "$SETUP_PROJECT/scripts/lib/target-user.sh" <<'MOCK'
target_user_resolve() {
    printf 'target\n' >> "$SETUP_TRACE"
    id -un
}
MOCK
printf '%s\n' 'printf "keyboard\n" >> "$SETUP_TRACE"' > "$SETUP_PROJECT/scripts/lib/keyboard-backlight-policy.sh"
printf '%s\n' 'printf "packages\n" >> "$SETUP_TRACE"' > "$SETUP_PROJECT/scripts/lib/modules/00-env.sh"
printf '%s\n' 'source "$PROJECT_ROOT/scripts/lib/keyboard-backlight-policy.sh"' > "$SETUP_PROJECT/scripts/lib/modules/91-suspend-resume.sh"
SETUP_TRACE="$KEYBOARD_SANDBOX/setup-trace"
run_setup_scope() {
    SETUP_TEST_EUID="${SETUP_TEST_EUID:-0}" KOS_LOG_STDOUT=1 SETUP_TRACE="$SETUP_TRACE" \
        KOS_I18N_DIR="$SETUP_PROJECT/scripts/lib/messages" bash "$SETUP_PROJECT/scripts/setup.sh" "$@"
}
: > "$SETUP_TRACE"
assert_true "keyboard setup scope runs without resolving an unrelated desktop user" "run_setup_scope --scope keyboard && [[ \"\$(cat '$SETUP_TRACE')\" == keyboard ]]"
: > "$SETUP_TRACE"
assert_false "unknown scope cannot fall through to a full system upgrade" "run_setup_scope --scope invalid"
assert_false "missing setup scope value is rejected" "run_setup_scope --scope"
assert_false "duplicate setup scopes are rejected" "run_setup_scope --scope keyboard --scope full"
assert_false "keyboard scope refuses desktop preview regeneration" "run_setup_scope --scope keyboard --rebuild-previews"
assert_false "keyboard scope rejects inherited preview regeneration" "KOS_REBUILD_PREVIEWS=1 run_setup_scope --scope keyboard"
assert_false "keyboard scope retains the privileged setup requirement" "SETUP_TEST_EUID=1000 run_setup_scope --scope keyboard"
assert_true "invalid and unprivileged scopes leave all stages untouched" "[[ ! -s '$SETUP_TRACE' ]]"
assert_true "default setup still runs the full module list" "run_setup_scope && [[ \"\$(cat '$SETUP_TRACE')\" == $'target\npackages\nkeyboard' ]]"

test_summary
