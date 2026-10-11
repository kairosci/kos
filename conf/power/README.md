The local `omaconf.power` plugin preserves Omarchy's panel and actions,
but does not infer a charge threshold pause from power or estimated time.
A battery in UPower's `Charging` state keeps its charging icon even during
slow charging. `PendingCharge` and `FullyCharged` below 99% retain the
original panel's threshold handling.

The installer runs through `make setup`, preserves bar position and settings,
and regenerates the clone from the installed Omarchy version.
An incompatible upstream structure stops installation before any changes.
The power module continues to own the 75% charge limit policy.

Keyboard backlight setup enables the hardware maximum at boot, on device registration and after resume. A device service runs after its native systemd brightness restore, so restoring a saved level cannot overwrite the requested maximum. The awake timer reconciles subsequent changes while sleep keeps the keyboard off. Missing interfaces are reported explicitly and every write is checked against hardware readback.

Run `make setup SCOPE=keyboard` to reconcile only the keyboard policy through the privileged setup pipeline. This scope installs the policy and its message runtime, reloads udev and enables the keyboard services without upgrading packages or running other system stages. The full setup uses the same policy script.
