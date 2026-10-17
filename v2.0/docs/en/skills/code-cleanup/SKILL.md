---
name: code-cleanup
description: >-
  Procedures for keeping Bash scripts, hooks, and tests free of decorative comments, banner echoes, emoji, and dead output code.
---

# Code Cleanup

## Overview
This skill defines what is noise and what stays. Every script, hook, module, and test across os and its subprojects (obscure, clean, slop, performance) must carry zero decoration: no banner output, no emoji, no narrative comments, no dead variables. Anything a machine or a test does not need is removed.

## Banned Output Patterns
Never emit separator or title banners. These exact shapes are forbidden in every file:
`echo -e "${BOLD}${CYAN}======================================================${NC}"`
and any variant built from `====`, `━━━━`, `────`, `▓`, or `█` repeated as visual rules, whether printed with `echo` or `printf`, whether colored or plain.
Test runners and verify scripts print one plain line per result and one plain summary line. The `[TEST SUITE]`, `pass`, `fail`, `warn` markers stay because the harness reads them; the surrounding decoration goes.

## Output Primitives
Always print with `printf '%s\n'` for plain text and `printf '%b\n'` only where ANSI color variables are interpolated. Never use `echo -e`. When a banner is removed and its color variable (commonly `CYAN`) becomes unused, delete the variable definition as well.

## Emoji Policy
No emoji in scripts, hooks, tests, installers, or generated configuration. The single exception class is functional glyphs asserted by tests: a glyph that a test greps for (for example the obscure Yazi lock indicator) is code, not decoration, and must stay untouched along with its assertion.

## Comment Policy
Keep shebang lines such as `#!/...` and Shellcheck directives such as `# shellcheck source=` or `# shellcheck disable=` because tools require them. Keep AppArmor `#include <...>` syntax inside profile heredocs because it is profile syntax. Keep fixture content inside heredocs when parsers or fake scripts require it, and preserve scope contracts asserted by tests, such as the slop module's exclusions for mise and tensaku. Delete other comments.
Delete narrative file headers, usage prose that duplicates `--help` or plan output, numbered section markers (`# 1. ...`), and any comment restating what the next lines already say. Never add comments to the Makefile or hook scripts.

## Procedure
Scan before every cleanup with ripgrep from the repository root:
`rg -n '====+|━━━━+|────+' --glob '*.sh' .`
`rg -n 'echo -e' .`
`rg -n '^\s*#[^!]' scripts/ hooks/ tests/ --glob '*.sh'`
`rg -l '\x{1F300}-\x{1FAFF}' .` for non-ASCII emoji ranges.
Classify each hit against the keep classes above, delete the rest, then verify with `shellcheck` and the full test suite (`lua -E tests/main.lua "$PWD" --group full` plus each subproject runner) before committing.
