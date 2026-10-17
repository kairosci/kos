#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Automation Idempotency & Safety Rules"

failed_upgrade_stops_setup() {
    local output status
    if output=$(bash -c '
        set -euo pipefail
        log() { :; }
        err() { exit 1; }
        pacman() {
            [[ "${OMARCHY_ALLOW_DIRECT_PACMAN:-}" == 1 ]] || exit 2
            printf "upgrade failure\n" >&2
            return 42
        }
        source "$1"
        printf "continued\n"
    ' bash "$PROJECT_DIR/scripts/lib/modules/00-env.sh" 2>&1); then
        return 1
    else
        status=$?
    fi
    [[ "$status" == 1 && "$output" == 'upgrade failure' ]]
}
assert_true "failed full upgrade halts setup and preserves diagnostics" "failed_upgrade_stops_setup"

assert_false "No unverified aur_install calls in setup.sh" "grep -q 'aur_install ' '$PROJECT_DIR/scripts/setup.sh' '$PROJECT_DIR'/scripts/lib/modules/*.sh"
assert_false "No yay -S invocations in setup scripts" "grep -q 'yay -S' '$PROJECT_DIR/scripts/setup.sh' '$PROJECT_DIR'/scripts/lib/modules/*.sh"

shell_sources() {
    local pattern file
    for pattern in \
        'scripts/*.sh' \
        'scripts/lib/*.sh' \
        'scripts/lib/modules/*.sh' \
        'hooks/theme-set.d/*' \
        'hooks/pre-refresh-pacman.d/*' \
        'hooks/post-update.d/*' \
        'modules/conf/*/install.sh' \
        '*/scripts/*.sh' \
        '*/scripts/lib/*.sh' \
        '*/scripts/lib/modules/*.sh' \
        '*/hooks/theme-set.d/*' \
        '*/hooks/pre-refresh-pacman.d/*' \
        '*/hooks/post-update.d/*' \
        'tests/*.sh' \
        '*/tests/*.sh'; do
        for file in $PROJECT_DIR/$pattern; do
            [[ -f "$file" ]] || continue
            [[ "$(basename "$file")" == "test_idempotency_safety.sh" ]] && continue
            printf '%s\n' "$file"
        done
    done
}

production_sources() {
    local pattern file
    for pattern in \
        'scripts/*.sh' \
        'scripts/lib/*.sh' \
        'scripts/lib/modules/*.sh' \
        'hooks/theme-set.d/*' \
        'hooks/pre-refresh-pacman.d/*' \
        'hooks/post-update.d/*' \
        'modules/conf/*/install.sh' \
        '*/scripts/*.sh' \
        '*/scripts/lib/*.sh' \
        '*/scripts/lib/modules/*.sh' \
        '*/hooks/theme-set.d/*' \
        '*/hooks/pre-refresh-pacman.d/*' \
        '*/hooks/post-update.d/*'; do
        for file in $PROJECT_DIR/$pattern; do
            [[ -f "$file" ]] && printf '%s\n' "$file"
        done
    done
}

mapfile -t ALL_SHELL_FILES < <(shell_sources | sort -u)
mapfile -t PRODUCTION_SHELL_FILES < <(production_sources | sort -u)

report_offenders() {
    local pattern="$1"
    shift
    local -a targets=("$@")
    awk -v pat="$pattern" \
        '$0 ~ pat { printf "    %s:%d: %s\n", FILENAME, FNR, $0 }' "${targets[@]}"
}

scan_all_shell() {
    report_offenders "$1" "${ALL_SHELL_FILES[@]}"
}

scan_production_shell() {
    report_offenders "$1" "${PRODUCTION_SHELL_FILES[@]}"
}

assert_true "Shell sources are discovered across the whole repository" "[[ \${#ALL_SHELL_FILES[@]} -gt 20 ]]"
assert_true "Production sources are discovered across the whole repository" "[[ \${#PRODUCTION_SHELL_FILES[@]} -gt 20 ]]"

assert_no_offenders "No raw '|| true' failure suppression" scan_all_shell '[|][|][[:space:]]*true([^[:alnum:]_]|$)'
assert_no_offenders "No raw '|| :' failure suppression" scan_all_shell '[|][|][[:space:]]*:([^:]|$)'
assert_no_offenders "No raw '|| false' failure suppression" scan_all_shell '[|][|][[:space:]]*false([^[:alnum:]_]|$)'
assert_no_offenders "No raw '|| null' failure suppression" scan_all_shell '[|][|][[:space:]]*null([^[:alnum:]_]|$)'
unguarded_early_exit() {
    awk '
        /[|][|][[:space:]]*exit[[:space:]]+0/ &&
        !/\]\][[:space:]]*[|][|][[:space:]]*exit[[:space:]]+0/ {
            printf "    %s:%d: %s\n", FILENAME, FNR, $0
        }' "${ALL_SHELL_FILES[@]}"
}

assert_no_offenders "No '|| exit 0' hides a failed command" unguarded_early_exit
assert_no_offenders "No silenced exit status through a redirected return" scan_all_shell '(return|exit)[[:space:]]+[0-9]+[[:space:]]+2>/dev/null'
assert_no_offenders "No silenced exit status through a redirected exit" scan_all_shell 'exit[[:space:]]+[0-9]+[[:space:]]*&>/dev/null'
assert_no_offenders "No silent '2>/dev/null' on a redirected command result" scan_all_shell '(command|curl|wget|pacman|systemctl|ufw|tee)[[:space:]][^|;&]*2>/dev/null[[:space:]]*(&>)?/dev/null'
assert_no_offenders "Production code never disables errexit" scan_production_shell '^[[:space:]]*set[[:space:]]+[+]e'
assert_no_offenders "Production code never disables pipefail" scan_production_shell '^[[:space:]]*set[[:space:]]+[+]o[[:space:]]+pipefail'
assert_no_offenders "Production code never traps failures into silence" scan_production_shell '(^|[^[:alnum:]_-])exec[[:space:]]+[0-9]+'

check_no_hardcoded_user_paths() {
    local offenders
    offenders=$(awk -v pat='/home/[a-zA-Z0-9_-]+/' \
        '$0 ~ pat && $0 !~ /(\/home\/\*|\/home\$|PRIMARY_USER)/ {
            printf "    %s:%d: %s\n", FILENAME, FNR, $0
        }' "${PRODUCTION_SHELL_FILES[@]}")
    [[ -z "$offenders" ]]
}

assert_true "No hardcoded specific user home paths in scripts" "check_no_hardcoded_user_paths"

test_summary
