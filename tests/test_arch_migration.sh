#!/usr/bin/env bash

ArchMigrationTest::run() {
    set -euo pipefail
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
    source "$SCRIPT_DIR/test_lib.sh"
    WORK_DIR=$(mktemp -d)
    trap 'rm -rf -- "$WORK_DIR"' EXIT
    mkdir -p "$WORK_DIR/bin"
    cat > "$WORK_DIR/bin/pacman" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ "${ARCH_TEST_FAIL:-0}" != 1 ]] || exit 44
case "$1" in
    -Qq) printf '%s\n' linux quickshell omarchy custom-app ;;
    -Slq) printf '%s\n' linux quickshell ;;
    -Qlq) printf '%s\n' /usr/share/omarchy/ /usr/share/omarchy/shell/shell.qml ;;
    -Q) [[ "${ARCH_TEST_NATIVE_ABSENT:-0}" != 1 ]] ;;
    *) exit 2 ;;
esac
SH
    cat > "$WORK_DIR/bin/pacman-conf" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' core extra multilib omarchy
SH
    chmod 755 "$WORK_DIR/bin/"*
    export PATH="$WORK_DIR/bin:$PATH"
    assert_true "migration inventory identifies packages without an official Arch source" "bash '$PROJECT_DIR/scripts/lib/arch-migration.sh' --report > '$WORK_DIR/report.json' && jq -e '.packagesWithoutOfficialSource == [\"omarchy\",\"custom-app\"] and .externalPackages == [\"omarchy\"] and .runtimeFileCount == 1 and (.dependentSources|length>0)' '$WORK_DIR/report.json'"
    assert_false "installed packages alone cannot authorize removal of the desktop runtime" "bash '$PROJECT_DIR/scripts/lib/arch-migration.sh' --check"
    assert_false "an absent runtime does not establish replacement parity" "ARCH_TEST_NATIVE_ABSENT=1 bash '$PROJECT_DIR/scripts/lib/arch-migration.sh' --check"
    assert_false "a package inventory error prevents a migration verdict" "ARCH_TEST_FAIL=1 bash '$PROJECT_DIR/scripts/lib/arch-migration.sh' --report"
    assert_true "all required capability areas retain an unverified verdict" "jq -e '(.capabilities|length==16) and all(.capabilities[]; .parity == \"unverified\") and (.readyToRemoveRuntime|not) and (.readyToRemoveRepository|not) and .requiresTrialBoot' '$WORK_DIR/report.json'"
    test_summary
}

ArchMigrationTest::run "$@"
