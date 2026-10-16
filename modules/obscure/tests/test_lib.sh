#!/bin/bash

set -uo pipefail

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

assert_true() {
    local desc="$1"
    local cmd="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if eval "$cmd" &>/dev/null; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        printf '%s\n' "  pass $desc"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf '%s\n' "  fail $desc"
    fi
}

assert_false() {
    local desc="$1"
    local cmd="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if ! eval "$cmd" &>/dev/null; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        printf '%s\n' "  pass $desc"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf '%s\n' "  fail $desc"
    fi
}

assert_warn() {
    local desc="$1"
    local cmd="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if eval "$cmd" &>/dev/null; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        printf '%s\n' "  pass $desc"
    else
        TESTS_WARNED=$((TESTS_WARNED + 1))
        printf '%s\n' "  warn $desc"
    fi
}

assert_file_exists() {
    local desc="$1"
    local file="$2"
    assert_true "$desc" "[[ -f '$file' ]]"
}

assert_file_executable() {
    local desc="$1"
    local file="$2"
    assert_true "$desc" "[[ -x '$file' ]]"
}

assert_file_contains() {
    local desc="$1"
    local file="$2"
    local pattern="$3"
    assert_true "$desc" "grep -qE '$pattern' '$file' 2>/dev/null"
}

test_section() {
    printf '\n%s\n' "[TEST SUITE] $1"
}

test_summary() {
    printf 'Summary: Tests Executed: %s | Passed: %s | Failed: %s | Warnings: %s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_WARNED"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        return 1
    fi
    return 0
}
