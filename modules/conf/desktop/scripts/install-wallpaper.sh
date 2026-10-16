#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "${BASH_SOURCE[0]%/*}/../../../.." && pwd -P)
exec "$root/script/os-lua" install-wallpapers "$@"
