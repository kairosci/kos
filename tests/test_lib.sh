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

assert_no_offenders() {
    local desc="$1"
    local scan="$2"
    shift 2
    local offenders scan_status=0
    offenders=$("$scan" "$@" | sed "s|${PROJECT_DIR:-.}/||g") || scan_status=$?
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ $scan_status -ne 0 ]]; then
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf '%s\n' "  fail $desc (scanner exited with status $scan_status)"
        [[ -z "$offenders" ]] || printf '%s\n' "$offenders"
    elif [[ -z "$offenders" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        printf '%s\n' "  pass $desc"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf '%s\n' "  fail $desc"
        printf '%s\n' "$offenders"
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

assert_file_not_contains() {
    local desc="$1"
    local file="$2"
    local pattern="$3"
    assert_false "$desc" "grep -qE '$pattern' '$file' 2>/dev/null"
}

assert_file_contains_literal() {
    local desc="$1"
    local file="$2"
    local needle="$3"
    assert_true "$desc" "grep -qF -e '$needle' '$file' 2>/dev/null"
}

test_priv() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
        return
    fi
    sudo -n "$@"
}

assert_equal() {
    local desc="$1"
    local actual="$2"
    local expected="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$actual" == "$expected" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        printf '%s\n' "  pass $desc"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf '%s\n' "  fail $desc (got '$actual', expected '$expected')"
    fi
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
