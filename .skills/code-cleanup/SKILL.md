---
name: code-cleanup
description: >-
  Procedures for keeping Bash scripts, hooks, and tests free of decorative comments, banner echoes, emoji, and dead output code.
---

# Code Cleanup

## Overview
This skill defines what is noise and what stays. Every script, hook, module, and test across kos and its subprojects (obscure, clean, ai, performance) must carry zero decoration: no banner output, no emoji, no narrative comments, no dead variables. Anything a machine or a test does not need is removed.

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
Keep exactly these comment classes and delete everything else:
- `#!/...` shebang lines.
- `# shellcheck ...` directives (`source=`, `disable=`); they drive the linter.
- AppArmor `#include <...>` lines inside profile heredocs; they are profile syntax, not comments.
- Test fixture data inside heredocs (commented config lines the parser under test must ignore, fake-script shebangs); removing them changes test semantics.
- Scope contracts asserted by tests (for example the ai module out-of-scope list covering mise and tensaku, which `ai/tests/check.sh` greps for); removing them breaks the suite.
Delete narrative file headers, usage prose that duplicates `--help` or plan output, numbered section markers (`# 1. ...`), and any comment restating what the next lines already say. Never add comments to the Makefile or hook scripts.

## Procedure
Scan before every cleanup with ripgrep from the repository root:
`rg -n '====+|━━━━+|────+' --glob '*.sh' .`
`rg -n 'echo -e' .`
`rg -n '^\s*#[^!]' scripts/ hooks/ tests/ --glob '*.sh'`
`rg -l '\x{1F300}-\x{1FAFF}' .` for non-ASCII emoji ranges.
Classify each hit against the keep classes above, delete the rest, then verify with `shellcheck` and the full test suite (`bash tests/run-all.sh` plus each subproject runner) before committing.
