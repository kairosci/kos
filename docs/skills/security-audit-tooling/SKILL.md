---
name: security-audit-tooling
description: >-
  Procedures for managing auditd rules, fail2ban jails, USBGuard policies, ClamAV virus scanning, and Lynis security scans.
---

# Security Audit Tooling

## Overview
This skill outlines how to maintain, configure, and verify host-based intrusion detection, peripheral device authorization, malware scanning, and automated system security audits on Arch Linux.

## Audit Framework Management
The Linux Audit daemon is configured through `/etc/audit/auditd.conf` while granular kernel audit rules reside in `/etc/audit/rules.d/`. Audit event logs are queried using `ausearch` and aggregated summary reports are generated using `aureport`. Daemon operational state is checked via `systemctl status auditd.service`.

## Intrusion Prevention with Fail2ban
Intrusion detection parameters are configured in `/etc/fail2ban/jail.local`. Active jails are monitored using `fail2ban-client status`, while banned IP addresses for specific services are reviewed with `fail2ban-client status sshd`.

## USB Device Authorization
Peripheral device authorization is enforced through the policy configuration file `/etc/usbguard/rules.conf`. The daemon blocks unauthorized USB storage and rogue devices while allowing recognized human interface input devices such as keyboards and mice. Connected USB hardware states are inspected using `usbguard list-devices`.

Generate the initial policy atomically only when no nonempty policy exists. Preserve established allow and block decisions on subsequent setup runs; do not automatically authorize newly attached devices by regenerating the policy.

## Antivirus and Security Audits
ClamAV signatures update through `clamav-freshclam.service` and `clamav-daemon.service` provides the scanning engine. The weekly audit scans `/home`, `/root`, `/etc`, `/usr`, `/opt`, `/var`, and `/boot` with `clamdscan --fdpass --multiscan --infected`; findings are logged to `/var/log/clamav/os-scan.log` and are never automatically removed. Arch package findings are recorded in `/var/log/arch-audit.log`; any advisory or package with a fixed upgrade fails the audit and requires review. The scan excludes pseudo-filesystems by targeting concrete system paths. Manual reports are generated using `lynis audit system` and rootkit checks run with `rkhunter --check --skip-keypress`.

`94-security-audit.sh` installs the shared weekly runner and timer. When Cronie is not enabled, setup enables `os-security-audit.timer` with persistent catch-up. Never enable both schedulers. Verify an enabled, active scheduler as well as the executable script. Freshclam runs through its daemon and is not repeated by the weekly audit. Retain two package versions with `paccache -rk2` for rollback.
