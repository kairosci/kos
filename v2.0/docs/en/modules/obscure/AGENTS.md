# Agent Guidelines and Codebase Knowledge

## Project Overview

obscure is the gaze protection microcomponent for OS on Arch Linux. It hides sensitive content with password gated yazi previews and native idle lock. It never touches documents and vaults and installed apps beyond preview and open gate.

## Repository Architecture

Provisioning in `scripts/setup.sh` loads this project's stage modules from `scripts/lib/modules/`. Verification runner in `scripts/verify.sh` asserts helper presence and per user gates and idle state. Modular test suite under `tests/` validates the Yazi gate and password helpers with isolated home and idle and syntax and pipeline and safety through `tests/main.lua`. Pattern globs live in the data patterns file and the Lua plugin lives in the data plugin folder. The password helper lives in `bin/` and installs system wide. Logging is managed by `scripts/run-setup.sh` and interactive execution is supported by `scripts/launch.sh`. Root Makefile exposes setup and verification and testing and cleanup targets. Operational runbook resides in `.skills/` with truly specific runbook only and shared runbooks living in profile repo.

## Ownership Details

Yazi stage holds glob read and preview and icon and open blocks and binary install and per home plugin copy and pattern copy and marker guarded appends and ownership fix. Idle stage holds removal of stay awake indicator and screensaver off toggle with native blank and lock preserved. Opener holds system password ask with fallback and verify with drop of timestamp and text page or pdf view or desktop open.

## Boundaries and Safety

Gating applies only to patterns in data file. Installed apps keep working through password gate. Home iteration guards with dir checks and home star paths. After debloat yazi reinstall this setup needs rerun. All changes validate with tests run file and scripts verify file.

## Commit Conventions

All commit messages follow Conventional Commits style with type and short description and colon as only punctuation after type. Titles hold never emoji and never exclamation and never extra punctuation.

## Scripting Rules and Structural Prompt

Apply the root `.skills/purist/SKILL.md` and register each new skill in the root `AGENTS.md`. Scripts use rigid mode in pure native Bash with zero Python deps. Failures never suppress with blind true. Non critical steps use warn function for graceful degrade. User paths never hardcode and derive from home variable or home star paths. All operations run in foreground with zero background runner. All modifications to setup and verify remain strictly idempotent. Single source holds for each rule with never scattered copies. Shared modules serve several places. Zero placeholders and zero fallbacks and zero temporary solutions and zero regressions and zero hand written values. Specific file names and touched paths and launched commands and expected results in each change. Full contract lives in profile repo inside docs folder with structured prompt and shared contract and critical review.
