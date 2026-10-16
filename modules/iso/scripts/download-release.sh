#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="${GITHUB_REPOSITORY:-kairosci/os}"
OUTPUT_DIR="${2:-$PWD}"
[[ -d "$OUTPUT_DIR" ]] || mkdir -p -- "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd -P)"

for dependency in curl jq sha256sum; do
    command -v "$dependency" >/dev/null 2>&1
done

if (($# == 0)); then
    TAG="$(curl -fsSL --retry 3 "https://api.github.com/repos/$REPOSITORY/releases/latest" | jq -er '.tag_name')"
else
    TAG="$1"
fi
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+$ ]]

ISO_NAME="os-${TAG}.iso"
CHECKSUM_NAME="$ISO_NAME.sha256"
WORK_DIR="$(mktemp -d "$OUTPUT_DIR/.os-iso-download.XXXXXXXX")"
cleanup() {
    rm -rf -- "$WORK_DIR"
}
trap cleanup EXIT

curl -fsSL --retry 3 \
    "https://api.github.com/repos/$REPOSITORY/releases/tags/$TAG" \
    --output "$WORK_DIR/release.json"
PARTS_JSON="$(jq -cer --arg prefix "$ISO_NAME.part-" \
    '[.assets[] | select(.name | startswith($prefix)) | {name, browser_download_url}] | sort_by(.name)' \
    "$WORK_DIR/release.json")"
[[ "$PARTS_JSON" != '[]' ]]
mapfile -t PART_NAMES < <(jq -r '.[].name' <<< "$PARTS_JSON")
CHECKSUM_URL="$(jq -er --arg name "$CHECKSUM_NAME" \
    '.assets[] | select(.name == $name) | .browser_download_url' "$WORK_DIR/release.json")"

expected_part=0
for part_name in "${PART_NAMES[@]}"; do
    part_number="${part_name##*.part-}"
    [[ "$part_number" =~ ^[0-9]{2,}$ ]]
    ((10#$part_number == expected_part))
    part_url="$(jq -er --arg name "$part_name" \
        '.assets[] | select(.name == $name) | .browser_download_url' "$WORK_DIR/release.json")"
    curl -fL --retry 3 --progress-bar --show-error "$part_url" --output "$WORK_DIR/$part_name"
    cat -- "$WORK_DIR/$part_name" >> "$WORK_DIR/$ISO_NAME"
    rm -- "$WORK_DIR/$part_name"
    ((expected_part += 1))
done

curl -fL --retry 3 --progress-bar --show-error "$CHECKSUM_URL" --output "$WORK_DIR/$CHECKSUM_NAME"
(cd "$WORK_DIR" && sha256sum -c "$CHECKSUM_NAME")
mv -f -- "$WORK_DIR/$ISO_NAME" "$OUTPUT_DIR/$ISO_NAME"
mv -f -- "$WORK_DIR/$CHECKSUM_NAME" "$OUTPUT_DIR/$CHECKSUM_NAME"
