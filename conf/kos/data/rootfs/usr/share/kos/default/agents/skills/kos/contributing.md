# Reporting Issues and Submitting PRs

Read this when the user wants to report an Kos bug, suggest a feature, or
contribute a fix upstream.

Kos lives at https://github.com/kairosci/kos. Route requests to the
right place:

- **Verified bugs** -> GitHub issues. Issues are for validated bugs only, not
  support requests.
- **Feature ideas and suggestions** ->
  https://github.com/kairosci/kos/discussions/categories/suggestions
- **Support and "is this a bug?" questions** -> the Discord community at
  https://github.com/kairosci/kos/issues. Start here when the problem isn't clearly a bug
  in Kos itself.

## Filing a Good Bug Report

The bug template asks for system details (CPU, GPU, Kos version), a
description with steps to reproduce, and diagnostics. Gather them:

```bash
kos version

# Generate the diagnostic log (also written to /tmp/kos-debug.log)
kos debug --no-sudo --print

# Interactive variant: `kos debug` offers to upload the log to
# local log storage (expires after 24h) and prints a shareable URL to
# include in the issue.
```

**Capture the problem on screen.** A screenshot or short recording of the bug
is often worth more than the description — see [`capture.md`](capture.md) for
`kos capture screenshot` and `kos screenrecord`. Keep recordings short
and focused on the misbehavior. GitHub issue attachments are added by
drag-and-drop in the web form, so save the capture and hand the user the file
path to attach (`gh` cannot upload media).

For screen-recording failures specifically, rerun with
`KOS_SCREENRECORD_DEBUG=true` and attach `/tmp/kos-screenrecord.log`.

File the issue with `gh` when available:

```bash
gh issue create --repo kairosci/kos --title "..." --body "..."
```

Include: what happened, what was expected, steps to reproduce, system details,
the debug log URL (or attached log), and the capture.

## Submitting a PR

Never develop against `/usr/share/kos`. Clone a working copy instead:

```bash
gh repo fork kairosci/kos --clone
cd kos
```

Follow the repository's own `AGENTS.md` for style, testing, and commit
conventions — it is the authority on contributions. Keep commits atomic, run
`./test/all` before pushing, and open the PR with `gh pr create`. A PR that
fixes a visual problem should include before/after captures (again, see
[`capture.md`](capture.md)).
