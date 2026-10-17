#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"

test_section "DNS Resolver Failover"
assert_file_contains "resolver installer delegates to Lua" "$PROJECT_DIR/scripts/lib/modules/81-resolver-failover.sh" "apply-resolver-failover"
assert_file_contains "resolver policy declares its service" "$PROJECT_DIR/data/component/security/resolver.json" "os-resolver-failover.service"
assert_file_contains "resolver runner uses Lua" "$PROJECT_DIR/data/component/security/resolver.json" "run-resolver-failover"
assert_file_contains "resolver uses independent update endpoints" "$PROJECT_DIR/data/component/security/resolver.json" "archlinux.org"
assert_file_contains "resolver policy retains cooldown protection" "$PROJECT_DIR/data/component/security/resolver.json" '"cooldownSeconds": 900'

test_summary
