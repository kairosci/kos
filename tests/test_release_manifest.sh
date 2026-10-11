#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/test_lib.sh"
source "$SCRIPT_DIR/../scripts/lib/release-manifest.sh"
source "$SCRIPT_DIR/../scripts/lib/release-query.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
manifest="$SANDBOX/PACKAGES.json"
jq -n '{release:"0.1.0", packages: ["kos", "linux-kos", "linux-kos-headers"] | map({name: ., version: "0.1.0-1", file: (. + "-0.1.0-1-x86_64.pkg.tar.zst"), sha256: ("a" * 64)})}' > "$manifest"
test_section "kos Release Verification"
assert_true "complete exact package manifest is accepted" 'kos_manifest_valid "$manifest" 0.1.0'
assert_false "different release version is rejected" 'kos_manifest_valid "$manifest" 0.2.0'
jq '.packages[1].file = "../outside.pkg.tar.zst"' "$manifest" > "$SANDBOX/unsafe.json"
assert_false "package path traversal is rejected" 'kos_manifest_valid "$SANDBOX/unsafe.json" 0.1.0'
jq '.packages[1].name = "unexpected"' "$manifest" > "$SANDBOX/unsafe.json"
assert_false "unexpected package names are rejected" 'kos_manifest_valid "$SANDBOX/unsafe.json" 0.1.0'
jq '.packages[1] = .packages[0]' "$manifest" > "$SANDBOX/unsafe.json"
assert_false "duplicates cannot replace a required package" 'kos_manifest_valid "$SANDBOX/unsafe.json" 0.1.0'
jq '.packages[1].sha256 = "unverified"' "$manifest" > "$SANDBOX/unsafe.json"
assert_false "invalid checksums are rejected" 'kos_manifest_valid "$SANDBOX/unsafe.json" 0.1.0'
curl() {
    local destination
    while (($#)); do
        if [[ $1 == -o ]]; then destination="$2"; shift; fi
        shift
    done
    printf '%s\n' "$RESPONSE" > "$destination"
    printf '%s' "$HTTP_STATUS"
}
HTTP_STATUS=404 RESPONSE='{}'
assert_true "missing first stable release has the no update status" 'status=0; kos_release_query stable "$SANDBOX/release.json" || status=$?; [[ "$status" == 1 ]]'
HTTP_STATUS=403
assert_true "API errors are distinct from no update" 'status=0; kos_release_query stable "$SANDBOX/release.json" || status=$?; [[ "$status" == 2 ]]'
HTTP_STATUS=200 RESPONSE='[{"tag_name":"v0.1.0","draft":false,"prerelease":true}]'
assert_true "preview channel accepts the public prerelease" 'kos_release_query preview "$SANDBOX/release.json" && jq -e '\''.tag_name == "v0.1.0"'\'' "$SANDBOX/release.json" >/dev/null'
RESPONSE='[]'
assert_true "empty preview history has the no update status" 'status=0; kos_release_query preview "$SANDBOX/release.json" || status=$?; [[ "$status" == 1 ]]'
assert_false "unknown release channels are rejected" 'kos_release_query unexpected "$SANDBOX/release.json"'
test_summary
