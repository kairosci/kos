#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$(dirname "$PROJECT_DIR")")"
source "$SCRIPT_DIR/test_lib.sh"
WORK_DIR=$(mktemp -d)
trap 'rm -rf -- "$WORK_DIR"' EXIT
cat > "$WORK_DIR/install.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$CLI_TEST_REPO"
install() {
    local argument
    local -a arguments=()
    for argument in "$@"; do
        [[ "${CLI_TEST_FAIL:-0}" != 1 || "$argument" != */modules/os/scripts/lib/app-launch.sh ]] || return 29
        case "$argument" in
            /usr/share/os*) argument="$CLI_TEST_ROOT$argument" ;;
            /usr/local/bin/os) argument="$CLI_TEST_ROOT$argument" ;;
        esac
        arguments+=("$argument")
    done
    command install "${arguments[@]}"
}
log() { printf '%s\n' "$1"; }
warn() { printf '%s\n' "$1" >&2; }
err() { printf '%s\n' "$1" >&2; exit 1; }
user_as() { return 0; }
mkdir -p "$CLI_TEST_ROOT/usr/local/bin"
source "$CLI_TEST_REPO/scripts/lib/modules/36-os-cli.sh"
SH
run_install() {
    CLI_TEST_REPO="$ROOT_DIR" CLI_TEST_ROOT="$WORK_DIR/root" CLI_TEST_FAIL="${CLI_TEST_FAIL:-0}" bash "$WORK_DIR/install.sh"
}
assert_true "CLI installer publishes its executable library role policy and catalogs" "run_install && cmp '$PROJECT_DIR/bin/os' '$WORK_DIR/root/usr/local/bin/os' && cmp '$PROJECT_DIR/scripts/lib/app-launch.sh' '$WORK_DIR/root/usr/share/os/lib/app-launch.sh' && cmp '$PROJECT_DIR/data/app-launch.json' '$WORK_DIR/root/usr/share/os/data/app-launch.json' && [[ \$(find '$WORK_DIR/root/usr/share/os/lib/messages' -name '*.msg' | wc -l) == 6 ]]"
first=$(find "$WORK_DIR/root" -type f -exec sha256sum {} + | sort | sha256sum)
assert_true "repeated CLI installation preserves every managed file" "run_install && [[ \$(find '$WORK_DIR/root' -type f -exec sha256sum {} + | sort | sha256sum) == '$first' ]]"
printf 'previous dispatcher\n' > "$WORK_DIR/root/usr/local/bin/os"
assert_false "a failed dependency installation aborts CLI publication" "CLI_TEST_FAIL=1 run_install"
assert_true "failed installation leaves the previous executable intact" "[[ \$(cat '$WORK_DIR/root/usr/local/bin/os') == 'previous dispatcher' ]]"
mkdir -p "$WORK_DIR/project/scripts/lib/modules"
sed 's/\$EUID/0/g' "$ROOT_DIR/scripts/setup.sh" > "$WORK_DIR/project/scripts/setup.sh"
cp "$ROOT_DIR/scripts/lib/i18n.sh" "$ROOT_DIR/scripts/lib/target-user.sh" "$WORK_DIR/project/scripts/lib/"
cp -r "$ROOT_DIR/data/catalog" "$WORK_DIR/project/scripts/lib/messages"
printf 'root_setup_persistent() { return 0; }\n' > "$WORK_DIR/project/scripts/lib/root-recovery.sh"
printf '[[ "${1:-}" == --functions-only ]] || exit 81\nprintf "helpers\\n" >> "$CLI_TEST_TRACE"\n' > "$WORK_DIR/project/scripts/lib/modules/00-env.sh"
printf 'printf "cli\\n" >> "$CLI_TEST_TRACE"\n' > "$WORK_DIR/project/scripts/lib/modules/36-os-cli.sh"
assert_true "CLI scope reaches only session helpers and its owned installer" "OS_LOG_STDOUT=1 CLI_TEST_TRACE='$WORK_DIR/trace' bash '$WORK_DIR/project/scripts/setup.sh' --scope cli && cmp -s '$WORK_DIR/trace' <(printf 'helpers\\ncli\\n')"
assert_false "CLI scope refuses unrelated full setup options" "OS_LOG_STDOUT=1 CLI_TEST_TRACE='$WORK_DIR/trace' bash '$WORK_DIR/project/scripts/setup.sh' --scope cli --reset-snapshots"
test_summary
