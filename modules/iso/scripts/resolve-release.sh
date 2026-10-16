#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
locale_init
TAG="${1:-}"
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+$ ]] || err iso.verify_ref_invalid "$TAG"
REPOSITORY="${GITHUB_REPOSITORY:-kairosci/os}"
BUILD_SHA=$(git -C "$PROJECT_DIR" rev-parse HEAD)
verify_tag() {
    local tag="$1" object details
    object=$(gh api "repos/$REPOSITORY/git/ref/tags/$tag") || return 1
    [[ $(jq -r '.object.type' <<< "$object") == tag ]] || return 1
    details=$(gh api "repos/$REPOSITORY/git/tags/$(jq -r '.object.sha' <<< "$object")") || return 1
    jq -e --arg commit "$BUILD_SHA" '.verification.verified == true and .object.type == "commit" and .object.sha == $commit' <<< "$details" > /dev/null
}
verify_tag "$TAG" || err iso.verify_ref_invalid "$TAG"
RELEASES=$(gh api --paginate "repos/$REPOSITORY/releases?per_page=100" | jq -s 'add // []')
jq -e --arg tag "$TAG" 'all(.[]; .tag_name != $tag)' <<< "$RELEASES" > /dev/null || err iso.release_exists "$TAG"
printf 'tag=%s\nbuild_sha=%s\niso_name=os-%s.iso\n' "$TAG" "$BUILD_SHA" "$TAG"
