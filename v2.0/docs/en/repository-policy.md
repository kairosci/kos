# Repository policy

[Italiano](../it/repository-policy.md) · [English](repository-policy.md) · [Français](../fr/repository-policy.md)

`v2.0/data/repository/main-ruleset.json`, exposed as `.github/main-ruleset.json`, is the canonical main protection policy. It targets `refs/heads/main` with active enforcement and no bypass actors: branch creation, deletion and force pushes are blocked, commits must be signed, history is linear, pull requests merge by squash only, no approval is mandatory, stale approvals are dismissed, threads must be resolved and the required status checks are evaluated against the latest base. The blanket update restriction stays disabled because, without bypass actors, it also blocks legitimate pull request merges.

The algorithm that verifies and applies this policy is `src/component/repository/policy.lua`, with command names in `data/core/commands.json` and its own policy in `data/repository/policy.json`. The component reads the canonical file, lists every ruleset page with `gh api --paginate --slurp`, resolves the canonical name across all pages and rejects an ambiguous duplicate. Applying the policy creates a missing ruleset with `POST` or updates the existing one with `PUT`, then reads it back and compares.

The comparison is structural. It verifies every canonical field, accepts the additional metadata and nested arrays the API returns, and distinguishes arrays from objects even when both are empty. Arrays must keep the same cardinality with the same elements regardless of order and including duplicates, so an extra rule, an added bypass actor or an update restriction is rejected before the local hook is satisfied. JSON `null` is compared explicitly and a missing canonical field fails.

The read-only entry point is `script/os-lua repository-policy-check <owner>/<repo>`; `repository-policy-apply` performs the mutation and must run only after a successful check. The `.githooks/pre-push` hook is a Lua entry point that reads the push records from standard input and refuses a direct or deleted `main` ref while allowing topic branches and repeated records; malformed records fail. Git runs the hook from the top level of the working tree, so its relative runtime paths resolve.

Verified commands require the GitHub CLI with an authenticated token, and applying protection is a privileged operation that needs the repository administration scope. Automated tests exercise the component through isolated backends and never call the live API, and the live server protection is inspected separately by the provenance workflow.
