#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$(dirname "$MODULE_DIR")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
i18n_init

OVERLAY_DIR="$MODULE_DIR/overlay"
OUTPUT_PATH=""
while (($#)); do
    case "$1" in
        --overlay|--output)
            (($# >= 2)) || err "iso.option_value" "$1"
            if [[ "$1" == --overlay ]]; then
                OVERLAY_DIR="$2"
            else
                OUTPUT_PATH="$2"
            fi
            shift 2
            ;;
        --help|-h)
            printf '%s\n' "$(t iso.usage)"
            exit 0
            ;;
        *)
            err "iso.invalid_option" "$1"
            ;;
    esac
done

for dependency in curl jq xorriso sha256sum find sort; do
    command -v "$dependency" >/dev/null 2>&1 || err "iso.dependency_missing" "$dependency"
done

[[ -d "$OVERLAY_DIR" ]] || err "iso.overlay_missing" "$OVERLAY_DIR"
OVERLAY_DIR="$(cd "$OVERLAY_DIR" && pwd -P)"

OVERLAY_ENTRIES="$(find "$OVERLAY_DIR" -mindepth 1 \! -type d \! -type f -print -quit)"
[[ -z "$OVERLAY_ENTRIES" ]] || err "iso.overlay_special" "$OVERLAY_ENTRIES"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/os/omarchy-iso"
mkdir -p "$CACHE_DIR"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/os-omarchy-iso.XXXXXXXX")"
OUTPUT_TEMP=""
cleanup() {
    [[ -z "$OUTPUT_TEMP" ]] || rm -f -- "$OUTPUT_TEMP" "$OUTPUT_TEMP.sha256"
    rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT

log "iso.release_query"
RELEASE_URL="https://api.github.com/repos/omacom/omarchy/releases/latest"
if ! curl -fsSL --retry 3 "$RELEASE_URL" --output "$WORK_DIR/release.json"; then
    err "iso.download_failed" "$RELEASE_URL"
fi
VERSION="$(jq -er '.tag_name | sub("^v"; "")' "$WORK_DIR/release.json")" || err "iso.release_invalid"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]] || err "iso.release_invalid"

ISO_NAME="omarchy-$VERSION.iso"
ISO_URL="https://iso.omarchy.org/$ISO_NAME"
CHECKSUM_URL="$ISO_URL.sha256"
ISO_PATH="$CACHE_DIR/$ISO_NAME"
CHECKSUM_PATH="$ISO_PATH.sha256"

iso_checksum_valid() {
    local expected actual
    [[ -f "$ISO_PATH" && -f "$CHECKSUM_PATH" ]] || return 1
    expected="$(awk 'NF {print $1; exit}' "$CHECKSUM_PATH")" || return 1
    [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || return 1
    actual="$(sha256sum "$ISO_PATH")" || return 1
    actual="${actual%% *}"
    [[ "${actual,,}" == "${expected,,}" ]]
}

if ! iso_checksum_valid; then
    log "iso.download" "$VERSION"
    if ! curl -fL --retry 3 "$ISO_URL" --output "$WORK_DIR/$ISO_NAME"; then
        err "iso.download_failed" "$ISO_URL"
    fi
    if ! curl -fsSL --retry 3 "$CHECKSUM_URL" --output "$WORK_DIR/$ISO_NAME.sha256"; then
        err "iso.download_failed" "$CHECKSUM_URL"
    fi
    mv -- "$WORK_DIR/$ISO_NAME" "$ISO_PATH"
    mv -- "$WORK_DIR/$ISO_NAME.sha256" "$CHECKSUM_PATH"
fi
iso_checksum_valid || err "iso.checksum_failed"

if [[ -z "$OUTPUT_PATH" ]]; then
    OUTPUT_PATH="$PWD/omarchy-$VERSION-custom.iso"
fi
OUTPUT_DIR="$(dirname "$OUTPUT_PATH")"
[[ -d "$OUTPUT_DIR" ]] || err "iso.output_dir" "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd -P)"
OUTPUT_NAME="$(basename "$OUTPUT_PATH")"
[[ "$OUTPUT_NAME" != . && "$OUTPUT_NAME" != .. ]] || err "iso.output_invalid"
OUTPUT_PATH="$OUTPUT_DIR/$OUTPUT_NAME"
[[ "$OUTPUT_PATH" != "$ISO_PATH" ]] || err "iso.output_same_input"
OUTPUT_TEMP="$(mktemp "$OUTPUT_DIR/.omarchy-custom.XXXXXXXX")"

mapfile -d '' -t OVERLAY_FILES < <(find "$OVERLAY_DIR" -type f ! -name .gitkeep -print0 | LC_ALL=C sort -z)
((${#OVERLAY_FILES[@]} > 0)) || err "iso.overlay_empty" "$OVERLAY_DIR"

log "iso.repacking"
XORRISO_ARGS=(-indev "$ISO_PATH" -outdev "$OUTPUT_TEMP" -overwrite on)
for overlay_file in "${OVERLAY_FILES[@]}"; do
    relative_path="${overlay_file#"$OVERLAY_DIR"/}"
    [[ "$relative_path" != "$overlay_file" && "$relative_path" != /* && "$relative_path" != .. && "$relative_path" != ../* && "$relative_path" != */../* ]] || err "iso.overlay_special" "$overlay_file"
    XORRISO_ARGS+=(-map "$overlay_file" "/$relative_path")
done
XORRISO_ARGS+=(-boot_image any replay -commit)
if ! xorriso "${XORRISO_ARGS[@]}"; then
    err "iso.repack_failed"
fi

[[ -s "$OUTPUT_TEMP" ]] || err "iso.repack_failed"
OUTPUT_CHECKSUM="$(sha256sum "$OUTPUT_TEMP")" || err "iso.checksum_failed"
OUTPUT_CHECKSUM="${OUTPUT_CHECKSUM%% *}"
printf '%s  %s\n' "$OUTPUT_CHECKSUM" "$(basename "$OUTPUT_PATH")" > "$OUTPUT_TEMP.sha256"
mv -f -- "$OUTPUT_TEMP" "$OUTPUT_PATH"
mv -f -- "$OUTPUT_TEMP.sha256" "$OUTPUT_PATH.sha256"
OUTPUT_TEMP=""
log "iso.output_ready" "$OUTPUT_PATH"
log "iso.signature_note"
