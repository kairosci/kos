#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG="$PROJECT_DIR/setup.log"

source "$SCRIPT_DIR/lib/i18n.sh"

locale_init

log "__log_in_progress" "$LOG"
log ""

pkexec bash "$SCRIPT_DIR/setup.sh"
