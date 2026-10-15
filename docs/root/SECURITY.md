# Security policy

## Supported versions

The latest version on the `main` branch is supported.

## Reporting a vulnerability

Please report suspected vulnerabilities through [GitHub private vulnerability reporting](https://github.com/kairosci/os/security/advisories/new). Include the affected file or component, steps to reproduce, and the impact. Do not disclose an unpatched issue publicly.

Security fixes are reviewed and released as soon as practical. Reports are acknowledged when maintainers are available.
## Free security automation

This public repository uses GitHub's standard hosted runners and security features without paid services or external API keys.

| Automation | Scope | Trigger |
| --- | --- | --- |
| Dependabot | Action, Python tooling and plugin dependency updates | Daily version checks and advisory-driven security PRs |
| GitHub secret scanning and push protection | Credentials and tokens | Pushes and newly published detection patterns |
| Gitleaks | Secrets in Git history | Push, PR and daily scan |
| Zizmor | GitHub Actions permissions, injection and supply chain | Push, PR and daily scan |
| Trivy | Vulnerable dependencies and misconfiguration | Push, PR and daily scan |
| Dependency review | Vulnerabilities introduced by dependency changes | PR |
| CodeQL | JavaScript security queries | Push, PR and daily scan |
| Semgrep and ShellCheck | Bash security and correctness | Push and PR; Semgrep also daily |
| OpenSSF Scorecard | Repository security posture | Main updates and daily scan |

The security gate requires every applicable scan to succeed. Dependency review rejects moderate or higher vulnerabilities, and Trivy and CodeQL reject high or critical findings. Every third-party action and the Arch CI container use immutable references. Dependabot updates those action references through PRs.

Patch remediation runs twice an hour. It only queues same-repository Dependabot PRs with verified bot commits and patch-only metadata. Maintainer changes, unsigned commits, minor updates and major updates require review. Auto-merge still requires the existing signed-commit, current-base, resolved-thread and CI/SAST/security rules; it has no bypass and never executes PR code with a write token.

Repository settings are recorded in `.github/security-settings.json`, with main protections in `.github/main-ruleset.json`. Dependency alerts and private vulnerability reporting are enabled through the GitHub API. Standard hosted runners are free for public repositories; private repositories or larger runners can have different billing.

Push and PR scans respond to repository changes; scheduled jobs depend on GitHub scheduling and may be delayed. Bots propose dependency fixes when an upstream patch exists. They cannot safely repair arbitrary application logic or rotate exposed secrets: those findings require maintainer action. These scans cover repository sources and manifests, not the packages currently installed on a user's Arch system.
