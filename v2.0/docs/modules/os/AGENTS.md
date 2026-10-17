# Agent Guidelines and Codebase Knowledge

## Project Overview

os is the command dispatcher microcomponent for OS on Arch Linux. It owns the os entrypoint that mirrors the native Omarchy command surface with hardened root handling and the prose changelog reader that reports what changed in each release.

## Repository Architecture

The dispatcher source lives in `modules/os/bin/os`. The setup stage module `scripts/lib/modules/36-os-cli.sh` installs the dispatcher to the system executable path and publishes `CHANGELOG.md` under the shared system directory before reconciling per user copies. Verification lives in `modules/os/tests/` through `tests/run-all.sh`. Canonical documentation lives in `docs/modules/os/` with symlinks at the module paths.

## Ownership Details

The dispatcher owns argument routing and session preparation and changelog extraction. The independent `os app` route resolves application roles through XDG preferences and launches desktop entries through UWSM without loading Omarchy. Its policy lives under `modules/os/data/` and its library under `modules/os/scripts/lib/`. All remaining group behavior stays delegated. It never writes service or desktop configuration state. The setup stage owns installation paths and permissions and ownership repair. The changelog file owns release narratives in prose without list markers.

## Boundaries and Safety

This module never provisions packages and never touches hardening or power or themes. It never hardcodes user homes and derives every per user path from existing home directories with presence guards. It never suppresses failures and propagates delegation exit codes unchanged. All changes validate with the module suite and the root syntax and pipeline suites.

## Commit Conventions

All commit messages follow Conventional Commits style with type and short description and colon as only punctuation after type. Titles hold never emoji and never exclamation and never extra punctuation.

## Scripting Rules

Scripts use rigid mode in pure native Bash with zero Python dependencies. Failures never suppress with blind true. Non critical steps use warn function for graceful degrade. All operations run in foreground with zero background runner. Installation remains strictly idempotent.
