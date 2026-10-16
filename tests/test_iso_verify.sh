#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
WORK_DIR=$(mktemp -d)
trap 'rm -rf -- "$WORK_DIR"' EXIT
VERIFY_SCRIPT="$PROJECT_DIR/modules/iso/scripts/verify-iso.sh"
RESOLVE_SCRIPT="$PROJECT_DIR/modules/iso/scripts/resolve-release.sh"
ISO_WORKFLOW="$PROJECT_DIR/.github/workflows/iso.yml"
assert_file_exists "verification script exists" "$VERIFY_SCRIPT"
assert_file_executable "verification script is executable" "$VERIFY_SCRIPT"
assert_true "verification script passes syntax check" "bash -n '$VERIFY_SCRIPT'"
assert_file_contains "verification script uses strict mode" "$VERIFY_SCRIPT" "set -euo pipefail"
assert_file_contains "verification script sources the i18n library" "$VERIFY_SCRIPT" "lib/i18n.sh"
assert_file_contains "verification script initializes i18n" "$VERIFY_SCRIPT" "i18n_init"
assert_true "verification script shows usage" "bash '$VERIFY_SCRIPT' --help"
assert_true "verification script rejects missing arguments" "! bash '$VERIFY_SCRIPT' --iso /nonexistent.iso"
assert_true "verification script rejects a missing image" "! bash '$VERIFY_SCRIPT' --iso /nonexistent.iso --ref HEAD"
assert_true "verification script rejects an invalid ref" "! bash '$VERIFY_SCRIPT' --iso '$VERIFY_SCRIPT' --ref refs/nonexistent/ref"
assert_true "verification script rejects an invalid expected commit" "! bash '$VERIFY_SCRIPT' --iso '$VERIFY_SCRIPT' --ref HEAD --expected-commit notasha"
assert_file_contains "verification script extracts the bundled tree" "$VERIFY_SCRIPT" "/opt/os"
assert_true "verification script does not rely on a release marker file" "! grep -q 'os-release.txt' '$VERIFY_SCRIPT'"
assert_file_contains "verification script compares materialized content" "$VERIFY_SCRIPT" "diff -qr -x .gitkeep"
assert_file_contains "verification script resolves the ref commit without trusting a marker" "$VERIFY_SCRIPT" '{commit}'
assert_file_contains "ISO workflow validates provenance in a resolve job" "$ISO_WORKFLOW" "^  resolve:"
assert_file_contains "ISO workflow builds the image in its own job" "$ISO_WORKFLOW" "^  build:"
assert_true "ISO workflow publishes stable releases without candidates" "! grep -q 'candidate' '$ISO_WORKFLOW'"
assert_file_contains "ISO workflow verifies in a separate job" "$ISO_WORKFLOW" "^  verify:"
assert_file_contains "ISO workflow publishes in a separate job" "$ISO_WORKFLOW" "^  release:"
assert_file_contains "ISO resolve job runs the release resolver" "$ISO_WORKFLOW" "resolve-release.sh"
assert_file_contains "ISO verify job waits for the build" "$ISO_WORKFLOW" "needs: .resolve, build."
assert_file_contains "ISO release job waits for verification" "$ISO_WORKFLOW" "needs: .resolve, verify."
assert_file_contains "ISO build shares the image through an artifact" "$ISO_WORKFLOW" "upload-artifact@"
assert_file_contains "ISO verify job fetches the image artifact" "$ISO_WORKFLOW" "download-artifact@"
assert_file_contains "ISO verify job runs the verification script" "$ISO_WORKFLOW" "verify-iso.sh"
assert_file_contains_literal "ISO verify job pins the expected build commit" "$ISO_WORKFLOW" "--expected-commit"
assert_true "ISO workflow never recreates history with force" "! grep -q 'force' '$ISO_WORKFLOW'"
assert_file_exists "release resolver exists" "$RESOLVE_SCRIPT"
assert_file_executable "release resolver is executable" "$RESOLVE_SCRIPT"
assert_true "release resolver passes syntax check" "bash -n '$RESOLVE_SCRIPT'"
assert_file_contains "release resolver requires a signed tag" "$RESOLVE_SCRIPT" "verification.verified"
assert_file_contains "release resolver refuses to modify an existing release" "$RESOLVE_SCRIPT" "release_exists"
assert_file_contains "release resolver accepts stable tags only" "$RESOLVE_SCRIPT" '\^v\[0-9\]'
mkdir -p "$WORK_DIR/bin" "$WORK_DIR/repo"
export PATH="$WORK_DIR/bin:$PATH"
REAL_GIT="$(command -v git)"
cat > "$WORK_DIR/bin/git" <<SH
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${FAKE_HEAD:-}" != "" && "\$1" == "-C" && "\$3" == "rev-parse" ]]; then
    printf '%s\n' "\$FAKE_HEAD"
    exit 0
fi
exec "$REAL_GIT" "\$@"
SH
chmod +x "$WORK_DIR/bin/git"
cat > "$WORK_DIR/bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
args="$*"
if [[ "$args" == *"git/ref/tags/"* ]]; then
    printf '{"object":{"type":"%s","sha":"%s"}}' "$GH_REF_TYPE" "$GH_TAG_SHA"
    exit 0
fi
if [[ "$args" == *"git/tags/"* ]]; then
    printf '{"verification":{"verified":%s},"object":{"type":"commit","sha":"%s"}}' "$GH_VERIFIED" "$GH_TAG_COMMIT"
    exit 0
fi
cat "$GH_RELEASES_JSON"
SH
chmod +x "$WORK_DIR/bin/gh"
FAKE_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
export FAKE_HEAD="$FAKE_SHA"
printf '[]' > "$WORK_DIR/empty.json"
printf '[{"tag_name":"v9.9","prerelease":false,"draft":false,"published_at":"2026-01-01T00:00:00Z"}]' > "$WORK_DIR/exists.json"
assert_true "resolver rejects an invalid tag format" "! bash '$RESOLVE_SCRIPT' bad-tag"
assert_true "resolver rejects a prerelease tag" "! bash '$RESOLVE_SCRIPT' v9.9-rc.1"
assert_true "resolver rejects a lightweight tag" "! GH_REF_TYPE=commit GH_TAG_SHA=abc GH_VERIFIED=true GH_TAG_COMMIT='$FAKE_SHA' GH_RELEASES_JSON='$WORK_DIR/empty.json' bash '$RESOLVE_SCRIPT' v9.9"
assert_true "resolver rejects an unsigned tag" "! GH_REF_TYPE=tag GH_TAG_SHA=abc GH_VERIFIED=false GH_TAG_COMMIT='$FAKE_SHA' GH_RELEASES_JSON='$WORK_DIR/empty.json' bash '$RESOLVE_SCRIPT' v9.9"
assert_true "resolver rejects a tag on another commit" "! GH_REF_TYPE=tag GH_TAG_SHA=abc GH_VERIFIED=true GH_TAG_COMMIT=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb GH_RELEASES_JSON='$WORK_DIR/empty.json' bash '$RESOLVE_SCRIPT' v9.9"
assert_true "resolver rejects an already published release" "! GH_REF_TYPE=tag GH_TAG_SHA=abc GH_VERIFIED=true GH_TAG_COMMIT='$FAKE_SHA' GH_RELEASES_JSON='$WORK_DIR/exists.json' bash '$RESOLVE_SCRIPT' v9.9"
assert_true "resolver resolves a signed stable tag" "GH_REF_TYPE=tag GH_TAG_SHA=abc GH_VERIFIED=true GH_TAG_COMMIT='$FAKE_SHA' GH_RELEASES_JSON='$WORK_DIR/empty.json' bash '$RESOLVE_SCRIPT' v9.9 | grep -q '^iso_name=os-v9.9.iso$'"
if command -v xorriso >/dev/null 2>&1; then
    printf 'fixture configuration\n' > "$WORK_DIR/repo/tracked.txt"
    git -C "$WORK_DIR/repo" add tracked.txt >/dev/null
    git -C "$WORK_DIR/repo" -c user.email=t@t -c user.name=t commit -qm fixture
    REF_SHA=$(git -C "$WORK_DIR/repo" rev-parse HEAD)
    mkdir -p "$WORK_DIR/overlay/opt/os" "$WORK_DIR/source"
    git -C "$WORK_DIR/repo" archive HEAD | tar -x -C "$WORK_DIR/source"
    cp -a "$WORK_DIR/source/." "$WORK_DIR/overlay/opt/os/"
    xorriso -as mkisofs -o "$WORK_DIR/good.iso" "$WORK_DIR/overlay" >/dev/null 2>&1
    assert_true "fixture ISO with exact content verifies" "bash '$VERIFY_SCRIPT' --iso '$WORK_DIR/good.iso' --ref HEAD --expected-commit '$REF_SHA'"
    printf 'altered\n' > "$WORK_DIR/overlay/opt/os/tracked.txt"
    xorriso -as mkisofs -o "$WORK_DIR/bad.iso" "$WORK_DIR/overlay" >/dev/null 2>&1
    assert_true "fixture ISO with altered content fails" "! bash '$VERIFY_SCRIPT' --iso '$WORK_DIR/bad.iso' --ref HEAD --expected-commit '$REF_SHA'"
    assert_true "fixture ISO with a wrong commit fails" "! bash '$VERIFY_SCRIPT' --iso '$WORK_DIR/good.iso' --ref HEAD --expected-commit '0000000000000000000000000000000000000000'"
else
    assert_warn "ISO content fixture requires xorriso" "command -v xorriso"
fi
test_summary
