#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf -- "$WORK_DIR"' EXIT
mkdir -p "$WORK_DIR/bin" "$WORK_DIR/assets" "$WORK_DIR/output directory"
export ISO_DOWNLOAD_FIXTURE="$WORK_DIR/assets"
printf 'first part\n' > "$WORK_DIR/assets/os-v1.4.iso.part-00"
printf 'second part\n' > "$WORK_DIR/assets/os-v1.4.iso.part-01"
cat "$WORK_DIR/assets/"*.part-* > "$WORK_DIR/assets/os-v1.4.iso"
(cd "$WORK_DIR/assets" && sha256sum os-v1.4.iso > os-v1.4.iso.sha256)
cat > "$WORK_DIR/assets/release.json" <<'JSON'
{"tag_name":"v1.4","assets":[{"name":"os-v1.4.iso.part-01","browser_download_url":"fixture/os-v1.4.iso.part-01"},{"name":"os-v1.4.iso.sha256","browser_download_url":"fixture/os-v1.4.iso.sha256"},{"name":"os-v1.4.iso.part-00","browser_download_url":"fixture/os-v1.4.iso.part-00"}]}
JSON
cat > "$WORK_DIR/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
output=""
url=""
while (($#)); do
    case "$1" in
        --output) output="$2"; shift 2 ;;
        --retry) shift 2 ;;
        -*) shift ;;
        *) url="$1"; shift ;;
    esac
done
case "$url" in
    */releases/*) asset=release.json ;;
    fixture/*) asset="${url##*/}" ;;
    *) exit 1 ;;
esac
if [[ -n "$output" ]]; then
    cp -- "$ISO_DOWNLOAD_FIXTURE/$asset" "$output"
else
    cat -- "$ISO_DOWNLOAD_FIXTURE/$asset"
fi
SH
chmod +x "$WORK_DIR/bin/curl"
export PATH="$WORK_DIR/bin:$PATH"
export TMPDIR="$WORK_DIR/nonexistent-tmp"
DOWNLOAD_SCRIPT="$PROJECT_DIR/modules/iso/scripts/download-release.sh"
OUTPUT_DIR="$WORK_DIR/output directory"
assert_true "download works without an available temporary filesystem" "bash '$DOWNLOAD_SCRIPT' v1.4 '$OUTPUT_DIR'"
assert_true "download assembles numbered parts in order" "cmp '$WORK_DIR/assets/os-v1.4.iso' '$OUTPUT_DIR/os-v1.4.iso'"
assert_true "download publishes a valid checksum" "(cd '$OUTPUT_DIR' && sha256sum -c os-v1.4.iso.sha256)"
assert_true "download removes temporary staging directories" "[[ -z \$(find '$OUTPUT_DIR' -mindepth 1 -type d -print -quit) ]]"
printf 'invalid checksum\n' > "$WORK_DIR/assets/os-v1.4.iso.sha256"
assert_true "download rejects an invalid checksum" "! bash '$DOWNLOAD_SCRIPT' v1.4 '$OUTPUT_DIR'"
assert_true "failed download preserves the existing image" "cmp '$WORK_DIR/assets/os-v1.4.iso' '$OUTPUT_DIR/os-v1.4.iso'"
assert_true "failed download removes temporary staging directories" "[[ -z \$(find '$OUTPUT_DIR' -mindepth 1 -type d -print -quit) ]]"
test_summary
