#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
lua -E "$SCRIPT_DIR/lua/run.lua" "$(dirname "$SCRIPT_DIR")" platform
