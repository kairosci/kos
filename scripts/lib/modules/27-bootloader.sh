#!/usr/bin/env bash
set -euo pipefail

source "$PROJECT_DIR/scripts/lib/grub-trial.sh"
"$PROJECT_DIR/script/os-lua" boot-appearance || err "bootloader.config_failed"
