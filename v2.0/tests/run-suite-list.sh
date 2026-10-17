#!/bin/bash

set -euo pipefail

TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
TOTAL_ASSERTIONS=0
SUITE_LOG=$(mktemp)
trap 'rm -f "$SUITE_LOG"' EXIT

for suite in "$@"; do
    TOTAL_SUITES=$((TOTAL_SUITES + 1))
    suite_name=$(basename "$suite")
    suite_failed=0
    if [[ -f "$suite" ]]; then
        if bash "$suite" >"$SUITE_LOG" 2>&1; then
            suite_status=0
        else
            suite_status=$?
            suite_failed=1
        fi
        cat "$SUITE_LOG"
        if grep -q '^  fail ' "$SUITE_LOG"; then
            suite_failed=1
        fi
        assertion_count=$(awk '/^  (pass|fail|warn) / { count++ } END { print count + 0 }' "$SUITE_LOG")
        reported_count=$(sed -nE 's/.*Summary: Tests Executed: ([0-9]+) \|.*/\1/p' "$SUITE_LOG" | tail -n 1)
        TOTAL_ASSERTIONS=$((TOTAL_ASSERTIONS + assertion_count))
        if [[ ! "$reported_count" =~ ^[0-9]+$ || "$reported_count" -ne "$assertion_count" ]]; then
            suite_failed=1
            printf '%s\n' "fail suite $suite_name reported an incorrect test count"
        fi
        if [[ $suite_status -ne 0 ]]; then
            printf '%s\n' "fail suite $suite_name"
        fi
    else
        suite_failed=1
        printf '%s\n' "fail suite $suite_name is missing"
    fi
    if [[ $suite_failed -eq 0 ]]; then
        PASSED_SUITES=$((PASSED_SUITES + 1))
    else
        FAILED_SUITES=$((FAILED_SUITES + 1))
    fi
done

printf 'Tests Executed: %s | Suites: %s | Passed: %s | Failed: %s\n' "$TOTAL_ASSERTIONS" "$TOTAL_SUITES" "$PASSED_SUITES" "$FAILED_SUITES"
[[ $FAILED_SUITES -eq 0 ]]
