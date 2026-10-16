#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ruby "$SCRIPT_DIR/../modules/core/tests/catalog_test.rb"
