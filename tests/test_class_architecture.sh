#!/usr/bin/env bash

ClassArchitectureTest::run() {
    set -euo pipefail
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
    source "$SCRIPT_DIR/test_lib.sh"
    local file first
    while IFS= read -r -d '' file; do
        [[ -f "$PROJECT_DIR/$file" && ! -L "$PROJECT_DIR/$file" ]] || continue
        first=''
        IFS= read -r first < "$PROJECT_DIR/$file" || [[ -n "$first" ]]
        case "$file:$first" in
            *.sh:*|*:'#!'*bash*)
                assert_true "Bash module has a namespaced method $file" "rg -q '^[a-zA-Z_][a-zA-Z_0-9:]*::[a-zA-Z_][a-zA-Z_0-9]*\\(\\)' '$PROJECT_DIR/$file'"
                ;;
            *.lua:*)
                assert_true "Lua module exposes a table method $file" "rg -q '^function [a-zA-Z_][a-zA-Z_0-9]*[.:]' '$PROJECT_DIR/$file'"
                ;;
            *.test.js:*)
                assert_true "JavaScript test suite has a class $file" "rg -q '^class ' '$PROJECT_DIR/$file'"
                ;;
            *.ps1:*)
                assert_true "PowerShell entry point has a native class $file" "rg -q '^class ' '$PROJECT_DIR/$file'"
                ;;
            *.html:*)
                assert_true "interactive preview has a class $file" "rg -q '^class ' '$PROJECT_DIR/$file'"
                ;;
        esac
    done < <(git -C "$PROJECT_DIR" ls-files -z)
    assert_true "sourced internationalization preserves caller options and its API" "bash -c 'set +e +u; source \"$PROJECT_DIR/scripts/lib/i18n.sh\"; [[ \$- != *e* && \$- != *u* ]] && declare -F i18n_init >/dev/null'"
    assert_true "functions only environment returns while exporting session methods" "bash -c 'source \"$PROJECT_DIR/scripts/lib/modules/00-env.sh\" --functions-only; declare -F user_as >/dev/null && declare -F omarchy_as >/dev/null'"
    test_summary
}

ClassArchitectureTest::run "$@"
