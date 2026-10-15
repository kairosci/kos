#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"

test_section "Limine Theme and Boot Integrity"

assert_file_exists "Limine theme module exists" "$PROJECT_DIR/scripts/lib/modules/27-limine-theme.sh"
assert_file_exists "Limine theme helper exists" "$PROJECT_DIR/scripts/lib/limine-theme.sh"
assert_file_exists "KMono boot wallpaper exists" "$PROJECT_DIR/modules/iso/assets/limine-wallpaper.png"
assert_file_contains "Limine theme keeps generated boot entries and inserts managed global settings" "$PROJECT_DIR/scripts/lib/limine-theme.sh" "OS_THEME_BEGIN"
assert_file_contains "Limine wallpaper is hash pinned" "$PROJECT_DIR/scripts/lib/limine-theme.sh" "b2sum"
assert_file_contains "Limine menu uses KMono cyan branding" "$PROJECT_DIR/scripts/lib/limine-theme.sh" "interface_branding_colour: 35D8E8"
assert_file_contains "Limine menu enables measured boot" "$PROJECT_DIR/scripts/lib/limine-theme.sh" "measured_boot: yes"
assert_file_contains "Limine rejects boot files with mismatched hashes" "$PROJECT_DIR/scripts/lib/limine-theme.sh" "hash_mismatch_panic: yes"
assert_file_contains "Limine theme is reapplied after generated config updates" "$PROJECT_DIR/scripts/lib/modules/27-limine-theme.sh" "/etc/boot/hooks/post.d/85-os-limine-theme"
assert_file_contains "Limine theme has a dedicated privileged setup scope" "$PROJECT_DIR/scripts/setup.sh" 'SETUP_SCOPE.*limine'
assert_file_contains "full setup includes Limine theme provisioning" "$PROJECT_DIR/scripts/setup.sh" "27-limine-theme.sh"

test_summary
