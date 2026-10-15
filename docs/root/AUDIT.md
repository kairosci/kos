# Verification on October 12, 2026

Configuration was applied through `make setup RUN_MIGRATIONS=1`. Setup completed successfully, and Hyprland reports no configuration errors. Caps Lock is no longer mapped to Compose on the physical keyboards; the Italian layout is preserved. Fcitx's virtual keyboard still exposes the previous option metadata. A physical key press remains necessary to confirm the user's observed behavior.

## Results

- Repository tests: 1457 assertions, all 29 suites passed.
- System verification: 166 checks passed, no failures.
- Shellcheck: passed.
- Zed: dark, light and dark transitions verified against the window pixels without restarting the process; verification repeated while capturing all 20 themes.
- Previews: the entire monitor was captured with its actual wallpaper, shell and applications; uniform export at 1800 × 1012, RGBA, depth 8 and density 72. Solitude and Matte Black were archived before removal from the theme catalog.
- Lynis: hardening index 80, no warnings and 22 suggestions.
- Semgrep 1.179.0 with the repository rule: no findings; six files have Bash parser errors or partial parsing. This is not comprehensive vulnerability coverage. Bash syntax and Shellcheck were verified separately.
- Required AppArmor profiles for sshd, useradd, curl and wget: enforce mode.
- Snapshots: snapshot zero and baseline 19 are preserved; snapshots 20 and 21 remain available.

## Package vulnerability assessment

`arch-audit --json` returns 23 records from the Arch Security database, including three High records and one Unknown record. Several records refer to CVEs from 2020–2022 and have no recorded fixed version. Each result requires comparison with the installed version; the raw output does not establish that all these vulnerabilities remain present.

All three High records were checked against official upstream or CNA records:

| Package | Installed version | Reported issues | Assessment |
| --- | --- | --- | --- |
| PAM | 1.7.2 | CVE-2025-6020 | Fixed in 1.7.1 according to the [official release notes](https://github.com/linux-pam/linux-pam/blob/master/NEWS). |
| DjVuLibre | 3.5.30.1 | CVE-2025-53367 | Fixed in 3.5.29 according to the [official CVE record](https://github.com/CVEProject/cvelistV5/blob/main/cves/2025/53xxx/CVE-2025-53367.json). |
| libxml2 | 2.15.4 | CVE-2025-6170, CVE-2025-49795, CVE-2025-49794 and CVE-2025-49796 | Outside the affected ranges: [6170](https://github.com/CVEProject/cvelistV5/blob/main/cves/2025/6xxx/CVE-2025-6170.json) and [49795](https://github.com/CVEProject/cvelistV5/blob/main/cves/2025/49xxx/CVE-2025-49795.json) affect versions below 2.14.5; [49794](https://github.com/CVEProject/cvelistV5/blob/main/cves/2025/49xxx/CVE-2025-49794.json) and [49796](https://github.com/CVEProject/cvelistV5/blob/main/cves/2025/49xxx/CVE-2025-49796.json) affect versions below 2.15.0. |

These three High records are stale for the installed versions. The other 20 records have not been individually adjudicated. No blanket claim of vulnerability absence is made. The database does not fully cover AUR and Omarchy packages.

## Remaining limitations

Lynis suggestions include tighter service isolation, password expiry, separate partitions, remote logging, file integrity monitoring and compiler restrictions. They were not applied automatically because they affect access, development, storage and desktop behavior and require specific requirements.

In the isolated capture session, Nautilus reports unavailable Mutter and Tracker services and network mounts. Its actual windows were verified and captured; no fictitious GNOME services were introduced and errors were not hidden. OSMP is installed from the canonical local sources through setup; the unavailable former plugin repository is no longer requested.

Execution logs are in `/tmp/os-final-setup.log`, `/tmp/os-final-tests.log`, `/tmp/os-final-verify.log`, `/tmp/os-final-lint.log`, `/tmp/os-final-semgrep.json`, `/tmp/os-package-audit.json` and `/tmp/os-lynis-output.log`. These are temporary local artifacts; privileged reports may be readable only by root.

## Follow-up on October 15, 2026

The current `arch-audit --json` check returned 23 tracker records and `arch-audit --upgradable` returned no package names. This does not close the 20 records that were not individually reviewed in the earlier assessment; the tracker includes records with no fixed version and needs package-by-package adjudication. The new weekly audit reports all tracker findings for review rather than treating an empty upgradable list as a clean bill of health.

ClamAV's updater and daemon are active, and its signature database was current at the time of inspection. The on-demand scan of `/home/krosci` ran for ten minutes and was stopped before completion; it reported no infected files before stopping, but produced repeated `cli_realpath: Invalid arguments` warnings for unsupported filesystem objects. This is not a clean scan verdict. The repository changes add a weekly scan of system and user paths, but the privileged setup scope could not be applied because this session had no interactive Polkit authentication agent. No live Limine or audit schedule changes were made.
