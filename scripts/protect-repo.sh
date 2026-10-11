#!/usr/bin/env bash
set -euo pipefail

BRANCH="main"

generate_payload() {
    cat <<'EOF'
{
  "enforce_admins": true,
  "restrictions": null,
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "syntax-integrity",
      "shellcheck-analysis",
      "idempotency-and-safety",
      "modular-pipeline-integrity",
      "theming-and-hook-engine",
      "arch-container-validation"
    ]
  },
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_signatures": true,
  "required_conversation_resolution": true
}
EOF
}

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <owner>/<repo> [branch]"
    echo "Example: $0 krosci/kos"
    exit 1
fi

REPO_ARG="$1"
if [[ $# -ge 2 ]]; then
    BRANCH="$2"
fi

if ! gh repo view "$REPO_ARG" &>/dev/null; then
    echo "Error: repo '$REPO_ARG' not found. Ensure gh is authenticated."
    exit 1
fi

OWNER="${REPO_ARG%%/*}"
REPOS_NAME="${REPO_ARG##*/}"

TMPFILE="$(mktemp)"
trap 'rm -f "$TMPFILE"' EXIT
generate_payload > "$TMPFILE"

echo "Applying branch protection to $OWNER/$REPOS_NAME ($BRANCH)..."
if gh api "repos/$OWNER/$REPOS_NAME/branches/$BRANCH/protection" -X PUT --input "$TMPFILE" >/dev/null; then
    echo "Branch protection successfully applied."
else
    echo "Failed to apply branch protection."
    exit 1
fi

echo "Done."