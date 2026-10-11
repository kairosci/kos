# Desktop responsiveness

The root setup pipeline loads `scripts/lib/modules/92-responsiveness.sh`.
This module installs the configuration in `data/` and reloads active user
managers through `user_as`. Inactive sessions receive it at their next login.
Apply changes exclusively with `make setup` from the repository root.

The observed failure was sustained memory reclaim during parallel Rust
documentation builds: a machine with 15 GiB RAM used approximately 26 GiB
of its 30 GiB swap, while disk pressure delayed interactive work. An earlier
systemd-oomd intervention had already terminated an application scope.

| Protection | Policy |
| --- | --- |
| Memory pressure | Monitor application and background slices at 40% for 10 seconds |
| Swap exhaustion | Act when both system memory and swap usage exceed 80% |
| Session CPU and I/O | Weight 200, versus the application default of 100 |
| Session memory | Best effort protection of 512 MiB through `MemoryLow`, propagated through its ancestors |
| Background CPU and I/O | Weight 25 |

These are conservative starting values, not benchmark results. CPU and I/O
weights allocate relative shares under contention; they do not cap application
throughput. `MemoryLow` is reclaim protection, not preallocated memory or an
absolute guarantee. I/O weighting depends on the storage stack and scheduler.
The compositor, shell, D-Bus and audio normally run in `session.slice` under
UWSM. The module monitors `app.slice` and `background.slice`, never the entire
user session. It does not restart the compositor or audio services.

Under sustained pressure, systemd-oomd can terminate an entire application
cgroup. A terminal, editor and build sharing a scope can all close together,
and unsaved work can be lost. Run large builds with bounded parallelism, for
example `cargo doc -j 2`, to reduce their peak memory demand. Applications
outside the monitored slices and kernel or hardware failures remain outside
this protection. No tuning can guarantee that an operating system never hangs.

Existing zram and disk swap are preserved, including hibernation configuration.
The module does not swap off a full device, change CPU governors, disable
watchdogs, change kernel hardening or install a second OOM daemon.

Generated configuration:

- `/etc/systemd/oomd.conf.d/90-omaconf.conf`
- `/etc/systemd/user/app.slice.d/90-omaconf.conf`
- `/etc/systemd/user/background.slice.d/90-omaconf.conf`
- `/etc/systemd/user/session.slice.d/90-omaconf.conf`
- `/etc/systemd/user/session.slice.d/90-omaconf-memory.conf`
- `/etc/systemd/system/user.slice.d/90-omaconf-memory.conf`
- `/etc/systemd/system/user-.slice.d/90-omaconf-memory.conf`
- `/etc/systemd/system/user@.service.d/90-omaconf-memory.conf`

`data/memory.slice.conf` is the single source of the memory protection value.
The service drop-in changes only the section header. The 512 MiB allowance
is shared among simultaneous users, then assigned to their core sessions;
it is not an unlimited reservation for every user.

Run `make verify` and `bash tests/test_responsiveness.sh`. Read-only diagnosis:

```bash
oomctl --no-pager
free -h
swapon --show
cat /proc/pressure/memory /proc/pressure/io
systemctl --user show app.slice background.slice session.slice
journalctl -b -u systemd-oomd --no-pager
```

The verifier compares installed files to their canonical templates and checks
the running daemon, its effective thresholds, and the current user's live
slice properties. Additional local overrides can invalidate these checks.

To roll back, revert the template changes on a feature branch and run root
`make setup` again. Keep the module in place so setup reconciles the previous
values rather than leaving stale installed overrides.

References: [systemd OOM configuration](https://github.com/systemd/systemd/blob/main/man/oomd.conf.xml)
and [systemd resource control](https://github.com/systemd/systemd/blob/main/man/systemd.resource-control.xml).
