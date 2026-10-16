#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "${BASH_SOURCE[0]%/*}/.." && pwd -P)
exec lua -E "$root/tests/lua/wallpaper.lua" "$root"
