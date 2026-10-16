#!/usr/bin/env bash

Os::modules::iso::scripts::verify_iso_sh::run() {
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$(dirname "$MODULE_DIR")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
i18n_init

ISO_PATH=""
REF=""
EXPECTED_COMMIT=""
while (($#)); do
    case "$1" in
        --iso|--ref|--expected-commit)
            (($# >= 2)) || err "iso.option_value" "$1"
            if [[ "$1" == --iso ]]; then
                ISO_PATH="$2"
            elif [[ "$1" == --ref ]]; then
                REF="$2"
            else
                EXPECTED_COMMIT="$2"
            fi
            shift 2
            ;;
        --help|-h)
            printf '%s\n' "$(t iso.verify_usage)"
            exit 0
            ;;
        *)
            err "iso.invalid_option" "$1"
            ;;
    esac
done

[[ -n "$ISO_PATH" && -n "$REF" ]] || err "iso.verify_usage"
[[ -f "$ISO_PATH" ]] || err "iso.verify_iso_missing" "$ISO_PATH"

command -v git >/dev/null 2>&1 || err "iso.dependency_missing" "git"
REF_COMMIT="$(git -C "$PROJECT_DIR" rev-parse --verify "$REF^{commit}" 2>/dev/null)" || err "iso.verify_ref_invalid" "$REF"
[[ -z "$EXPECTED_COMMIT" || "$EXPECTED_COMMIT" == "$REF_COMMIT" ]] || err "iso.verify_ref_invalid" "$EXPECTED_COMMIT"

for dependency in xorriso tar diff cmp find sort; do
    command -v "$dependency" >/dev/null 2>&1 || err "iso.dependency_missing" "$dependency"
done

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/os-iso-verify.XXXXXXXX")"
cleanup() {
    rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$WORK_DIR/source" "$WORK_DIR/materialized" "$WORK_DIR/image"
git -C "$PROJECT_DIR" archive "$REF" | tar -x -C "$WORK_DIR/source"
cp -aL "$WORK_DIR/source/." "$WORK_DIR/materialized/"

mkdir -p "$WORK_DIR/image/os"
if ! xorriso -osirrox on -indev "$ISO_PATH" -extract /opt/os "$WORK_DIR/image/os" >/dev/null 2>&1; then
    err "iso.verify_extract_failed" "$ISO_PATH"
fi

if ! diff -qr -x .gitkeep "$WORK_DIR/materialized" "$WORK_DIR/image/os" >"$WORK_DIR/diff.out" 2>&1; then
    cat -- "$WORK_DIR/diff.out"
    err "iso.verify_content_mismatch"
fi

log "iso.verify_ok" "$ISO_PATH"

}

Os::modules::iso::scripts::verify_iso_sh::run "$@"
