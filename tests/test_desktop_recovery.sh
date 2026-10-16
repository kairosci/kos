#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/snapshot-baseline.sh"
source "$PROJECT_DIR/scripts/lib/omarchy-restore.sh"
locale_init
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export OS_SNAPSHOT_BASELINE_STATE="$SANDBOX/state"
export SNAPSHOT_TEST_ROWS="$SANDBOX/rows" SNAPSHOT_TEST_COMMANDS="$SANDBOX/commands"
printf '0,no,yes\n1,no,no\n2,yes,no\n3,no,yes\n4,no,no\n' > "$SNAPSHOT_TEST_ROWS"
snapper() {
    printf '%s\n' "$*" >> "$SNAPSHOT_TEST_COMMANDS"
    case " $* " in
        *' list-configs '*) printf 'root\n' ;;
        *' list '*) cat "$SNAPSHOT_TEST_ROWS" ;;
        *' create '*)
            [[ ${SNAPSHOT_TEST_CREATE_FAIL:-0} == 0 ]] || return 1
            printf '5,no,no\n6,no,no\n' >> "$SNAPSHOT_TEST_ROWS"
            printf '5\n'
            ;;
        *' delete '*)
            [[ ${SNAPSHOT_TEST_DELETE_FAIL:-0} == 0 ]] || return 1
            local argument
            for argument in "$@"; do
                if [[ "$argument" =~ ^[1-9][0-9]*$ ]]; then
                    sed -i "/^$argument,/d" "$SNAPSHOT_TEST_ROWS"
                fi
            done
            ;;
        *) return 1 ;;
    esac
}
grub-mkconfig() { printf 'grub\n' >> "$SNAPSHOT_TEST_COMMANDS"; }
test_section "Omarchy restore and Snapper baseline"
assert_true "baseline is created and earlier removable snapshots are deleted" 'snapshot_baseline_reset && ! grep -qE "^(1|4)," "$SNAPSHOT_TEST_ROWS" && grep -q "^5," "$SNAPSHOT_TEST_ROWS"'
assert_true "active and default snapshots survive" 'grep -q "^0," "$SNAPSHOT_TEST_ROWS" && grep -q "^2," "$SNAPSHOT_TEST_ROWS" && grep -q "^3," "$SNAPSHOT_TEST_ROWS"'
assert_true "snapshots created after the baseline survive" 'grep -q "^6," "$SNAPSHOT_TEST_ROWS"'
assert_true "deletion synchronizes reclaimed space" 'grep -qx -- "-c root delete --sync 1 4" "$SNAPSHOT_TEST_COMMANDS"'
assert_true "GRUB snapshot entries are regenerated after deletion" '[[ $(tail -1 "$SNAPSHOT_TEST_COMMANDS") == grub ]]'
assert_true "baseline creation precedes deletion" '[[ $(grep -n " create " "$SNAPSHOT_TEST_COMMANDS" | cut -d: -f1) -lt $(grep -n " delete " "$SNAPSHOT_TEST_COMMANDS" | cut -d: -f1) ]]'
assert_true "repeated reset does not recreate the recorded baseline" 'snapshot_baseline_reset && [[ $(grep -c " create " "$SNAPSHOT_TEST_COMMANDS") == 1 ]]'
export OS_SNAPSHOT_BASELINE_STATE="$SANDBOX/failure-state"
printf '0,no,yes\n1,no,no\n' > "$SNAPSHOT_TEST_ROWS"
: > "$SNAPSHOT_TEST_COMMANDS"
assert_false "failed baseline creation halts deletion" 'SNAPSHOT_TEST_CREATE_FAIL=1 snapshot_baseline_reset'
assert_true "failed creation preserves every previous snapshot" 'grep -q "^1," "$SNAPSHOT_TEST_ROWS" && ! grep -q " delete " "$SNAPSHOT_TEST_COMMANDS"'
printf '0,unknown,no\n' > "$SNAPSHOT_TEST_ROWS"
: > "$SNAPSHOT_TEST_COMMANDS"
assert_false "malformed snapshot flags fail before mutation" 'snapshot_baseline_reset'
assert_true "malformed inventory cannot create or delete snapshots" '! grep -qE " (create|delete) " "$SNAPSHOT_TEST_COMMANDS"'
printf '0,no,yes\n1,no,no\n' > "$SNAPSHOT_TEST_ROWS"
assert_false "failed deletion is not reported as success" 'SNAPSHOT_TEST_DELETE_FAIL=1 snapshot_baseline_reset'
assert_true "failed deletion retains the new baseline and previous recovery point" 'grep -q "^1," "$SNAPSHOT_TEST_ROWS" && grep -q "^5," "$SNAPSHOT_TEST_ROWS"'

export OMARCHY_PATH="$SANDBOX/upstream" OS_RESTORE_BACKUP_ROOT="$SANDBOX/restore" OS_RESTORE_BASHRC="$SANDBOX/skel-bashrc"
RESTORE_HOME="$SANDBOX/home"
RESTORE_USER=$(id -un)
mkdir -p "$OMARCHY_PATH/config/hypr" "$OMARCHY_PATH/config/omarchy" "$RESTORE_HOME/.config/hypr" "$RESTORE_HOME/.config/omarchy" "$RESTORE_HOME/.config/os"
printf 'native Omarchy\n' > "$OMARCHY_PATH/config/hypr/hyprland.lua"
printf '{}\n' > "$OMARCHY_PATH/config/omarchy/shell.json"
printf 'native bash\n' > "$OS_RESTORE_BASHRC"
printf 'personal Hyprland\n' > "$RESTORE_HOME/.config/hypr/hyprland.lua"
printf 'personal shell\n' > "$RESTORE_HOME/.config/omarchy/shell.json"
printf 'personal OS\n' > "$RESTORE_HOME/.config/os/shell.json"
printf 'personal Bash\n' > "$RESTORE_HOME/.bashrc"
printf 'older Bash backup\n' > "$RESTORE_HOME/.bashrc.bak"
user_as() { shift; HOME="$RESTORE_HOME" "$@"; }
chown() { printf '%s\n' "$*" >> "$SANDBOX/ownership"; }
assert_true "restore replaces defaults after preserving personal configurations" 'omarchy_restore_user "$RESTORE_USER" "$RESTORE_HOME" && cmp "$OMARCHY_PATH/config/hypr/hyprland.lua" "$RESTORE_HOME/.config/hypr/hyprland.lua" && grep -qx "personal Hyprland" "$OS_RESTORE_BACKUP_ROOT/$RESTORE_USER/.config/hypr/hyprland.lua"'
assert_true "restore preserves old shell and Bash configurations" 'grep -qx "personal shell" "$OS_RESTORE_BACKUP_ROOT/$RESTORE_USER/.config/omarchy/shell.json" && grep -qx "personal Bash" "$OS_RESTORE_BACKUP_ROOT/$RESTORE_USER/.bashrc" && cmp "$OS_RESTORE_BASHRC" "$RESTORE_HOME/.bashrc"'
assert_true "restore archives the existing Bash backup and repairs its ownership" 'grep -qx "older Bash backup" "$OS_RESTORE_BACKUP_ROOT/$RESTORE_USER/.bashrc.bak" && grep -Fxq "$RESTORE_USER:$RESTORE_USER $RESTORE_HOME/.bashrc.bak" "$SANDBOX/ownership"'
assert_true "old OS configurations remain available" 'grep -qx "personal OS" "$RESTORE_HOME/.config/os/shell.json" && grep -qx "personal OS" "$OS_RESTORE_BACKUP_ROOT/$RESTORE_USER/.config/os/shell.json"'
printf 'later custom setting\n' > "$RESTORE_HOME/.config/hypr/hyprland.lua"
assert_true "repeated restore preserves later custom settings and the initial backup" 'omarchy_restore_user "$RESTORE_USER" "$RESTORE_HOME" && grep -qx "later custom setting" "$RESTORE_HOME/.config/hypr/hyprland.lua" && grep -qx "personal Hyprland" "$OS_RESTORE_BACKUP_ROOT/$RESTORE_USER/.config/hypr/hyprland.lua"'
assert_false "restore rejects a linked home directory" 'ln -s "$RESTORE_HOME" "$SANDBOX/linked-home" && omarchy_restore_user "$RESTORE_USER" "$SANDBOX/linked-home"'
assert_file_contains_literal "snapshot reset occurs only after all setup stages" "$PROJECT_DIR/scripts/setup.sh" 'snapshot_baseline_reset || err "snapshots.failed"'
source "$PROJECT_DIR/scripts/lib/retired-config.sh"
mkdir -p "$RESTORE_HOME/.config/nvim/lua/config"
printf 'personal editor settings\n' > "$RESTORE_HOME/.config/nvim/lua/config/options.lua"
assert_true "retired Neovim config is preserved outside native migration detection" 'retire_user_config "$RESTORE_USER" "$RESTORE_HOME" nvim && [[ ! -e "$RESTORE_HOME/.config/nvim" ]] && grep -qx "personal editor settings" "$RESTORE_HOME"/.local/state/omarchy/retired/nvim.*/config/lua/config/options.lua'
assert_true "retiring Neovim again preserves one archive" 'retire_user_config "$RESTORE_USER" "$RESTORE_HOME" nvim && [[ $(find "$RESTORE_HOME/.local/state/omarchy/retired" -mindepth 1 -maxdepth 1 -type d | wc -l) == 1 ]]'
assert_false "retirement rejects a linked configuration without moving its target" 'ln -s "$SANDBOX/upstream" "$RESTORE_HOME/.config/nvim" && retire_user_config "$RESTORE_USER" "$RESTORE_HOME" nvim'
for option in --restore-omarchy --reset-snapshots --run-migrations; do
    assert_false "keyboard scope rejects $option" "OS_LOG_STDOUT=1 bash '$PROJECT_DIR/scripts/setup.sh' --scope keyboard '$option'"
done

source "$PROJECT_DIR/scripts/lib/namespace-cleanup.sh"
export OS_NAMESPACE_ROOT="$SANDBOX/namespace-root" OS_NAMESPACE_OWNER_UID
OS_NAMESPACE_OWNER_UID=$(id -u)
mkdir -p "$OS_NAMESPACE_ROOT/usr/local/lib/oldos" "$OS_NAMESPACE_ROOT/etc/systemd/system" "$OS_NAMESPACE_ROOT/etc/pacman.d/hooks"
printf 'declare -gA OLDOS_I18N=()\n' > "$OS_NAMESPACE_ROOT/usr/local/lib/oldos/i18n.sh"
printf 'ExecStart=/etc/cron.weekly/security-audit.sh\n' > "$OS_NAMESPACE_ROOT/etc/systemd/system/oldos-security-audit.service"
printf '[Timer]\nOnCalendar=weekly\n' > "$OS_NAMESPACE_ROOT/etc/systemd/system/oldos-security-audit.timer"
printf 'ExecStart=/usr/local/libexec/oldos-keyboard-backlight\n' > "$OS_NAMESPACE_ROOT/etc/systemd/system/oldos-keyboard-backlight.service"
printf 'ExecStart=/usr/local/libexec/oldos-keyboard-backlight --device %%i\n' > "$OS_NAMESPACE_ROOT/etc/systemd/system/oldos-keyboard-backlight@.service"
printf 'managed hook\n' > "$OS_NAMESPACE_ROOT/etc/pacman.d/hooks/99-oldos-theme-previews.hook"
printf 'unrelated\n' > "$OS_NAMESPACE_ROOT/etc/systemd/system/os-security-audit.service"
printf 'unrelated\n' > "$OS_NAMESPACE_ROOT/etc/systemd/system/other-security-audit.timer"
export NAMESPACE_TEST_COMMANDS="$SANDBOX/namespace-commands"
systemctl() {
    printf '%s\n' "$*" >> "$NAMESPACE_TEST_COMMANDS"
    if [[ "$1" == list-units ]]; then
        printf 'oldos-keyboard-backlight@device.service loaded active exited\n'
    fi
}
assert_true "namespace cleanup retires previous owned timers and device units" 'namespace_cleanup && grep -qx "disable --now oldos-security-audit.timer" "$NAMESPACE_TEST_COMMANDS" && grep -qx "stop oldos-keyboard-backlight@device.service" "$NAMESPACE_TEST_COMMANDS"'
assert_true "previous units and hooks are archived" '[[ -f "$OS_NAMESPACE_ROOT/var/lib/os/previous-namespace/oldos/etc/systemd/system/oldos-security-audit.service" && -f "$OS_NAMESPACE_ROOT/var/lib/os/previous-namespace/oldos/etc/pacman.d/hooks/99-oldos-theme-previews.hook" && ! -e "$OS_NAMESPACE_ROOT/etc/systemd/system/oldos-security-audit.timer" ]]'
assert_true "namespace cleanup preserves current and unrelated units" '[[ -f "$OS_NAMESPACE_ROOT/etc/systemd/system/os-security-audit.service" && -f "$OS_NAMESPACE_ROOT/etc/systemd/system/other-security-audit.timer" ]]'
assert_true "repeated namespace cleanup is idempotent" 'namespace_cleanup && [[ $(grep -c "disable --now oldos-security-audit.timer" "$NAMESPACE_TEST_COMMANDS") == 1 ]]'
printf 'Description=Earlier security audit\nExecStart=/etc/cron.weekly/security-audit.sh\n' > "$OS_NAMESPACE_ROOT/etc/systemd/system/earlier-security-audit.service"
printf '[Timer]\nOnCalendar=weekly\n' > "$OS_NAMESPACE_ROOT/etc/systemd/system/earlier-security-audit.timer"
assert_true "canonical previous audit units are retired without an i18n library" 'namespace_cleanup && grep -qx "disable --now earlier-security-audit.timer" "$NAMESPACE_TEST_COMMANDS" && [[ ! -e "$OS_NAMESPACE_ROOT/etc/systemd/system/earlier-security-audit.service" ]]'
test_summary
