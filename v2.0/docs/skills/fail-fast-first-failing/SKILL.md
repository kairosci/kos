---
name: fail-fast-first-failing
description: >-
  Procedures and standards for enforcing the fail-fast and first-failing principle: eliminating silent failures, banning unhandled error suppressions, and ensuring immediate visibility on errors.
---

# Fail-Fast and First-Failing Principle

## Overview
This skill defines the engineering discipline and standards for building software that fails immediately and visibly at the earliest point of error. In robust systems automation and security hardening, silent failures, swallowed exit codes, and unchecked assumptions mask underlying defects, corrupt system state, and impede diagnostics. Every operation must either succeed cleanly or fail loudly and informatively.

## Core Tenets
First-failing detection means recording a failure at the first instruction that encounters an unexpected condition, which prevents cascaded or corrupted downstream states. Zero silent failures means commands never suppress failures without a checked fallback or an error report; blanket catch-alls such as `|| true`, `|| null`, and unmonitored redirects to `/dev/null` are forbidden. Explicit error boundaries distinguish fatal errors that must halt execution through `err` from non-critical operations that may degrade through `warn`, and every graceful degradation emits a structured, localized diagnostic. Deterministic exit codes require subshells, pipelines and helper functions to propagate statuses accurately under `set -euo pipefail`.

## Implementation Rules
Use `set -euo pipefail` in shell scripts. Never use `|| true` to mask errors; use `|| warn "message.key"` for optional degradation with a diagnostic, or `|| err "message.key"` for fatal requirements. Avoid unchecked command substitutions and silent stderr redirection unless a condition explicitly validates the output. Check package states, file paths and service status with commands such as `pacman -Q`, `systemctl is-active` and `[[ -f ... ]]` before mutations. Ensure subprocesses, terminal wrappers and IPC channels preserve and propagate standard error streams.
