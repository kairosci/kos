---
name: purist
description: >-
  Keep repository changes minimal, consistent, secure, and free of decorative or redundant content.
---

# Purist

## Scope

Apply this runbook to every repository change. Treat configuration, code, tests, documentation, workflows, and Git history as maintained interfaces.

## Rules

Make the smallest complete change that satisfies the request. Remove dead code, unused dependencies, duplicate configuration, redundant whitespace, decorative output, emoji and nonfunctional glyphs. Remove narrative comments while keeping shebangs, linter directives, parser fixtures and syntax required by embedded formats. Preserve behavior unless the request explicitly changes it, and trace callers, tests, generated files, installers and recovery paths before removing or moving anything. Keep each setting and policy in one canonical file, avoiding compatibility aliases unless a live caller requires one. Use native project tools and pinned, maintained dependencies, and do not add a dependency to solve a problem an existing tool handles.

Fail visibly on invalid input and failed required operations. Keep tests meaningful and deterministic, and make them report the number of assertions actually executed. Run the narrowest relevant checks, followed by the full repository checks for cross-cutting changes. Work on a feature branch and use a pull request; never push directly to `main` or rewrite published `main` history. Register every new skill in the root `AGENTS.md` inventory in the same change.

## Review

Before committing, inspect the complete diff for behavior drift, duplication, generated noise, accidental whitespace, comments, glyphs, unsafe shell patterns, and untested paths. Confirm the worktree is clean after committing and the feature branch is pushed for review.

## Required Context and Main Protection

Read every local `.skills/*/SKILL.md` at the start of each task as required by root `AGENTS.md`; keep its skill inventory synchronized in every skill change. Preserve functional config block markers alongside shebangs, linter directives and parser fixtures.

Use `.github/main-ruleset.json` as the canonical main protection policy. Require signed commits, linear history, squash-only PRs, no mandatory approvals, dismissal of stale approvals, no additional latest push approval, resolved threads and up-to-date CI and SAST checks. Allow no bypass actors, branch recreation, deletion or force pushes. Never lock all updates because that also prevents PR merges. Already published main commits cannot be moved retroactively without rewriting history; propose corrective PRs instead.
