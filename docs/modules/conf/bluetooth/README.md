# Bluetooth

Setup installs a local clone of the packaged Bluetooth panel and preserves its bar position. The clone queries BlueZ `Adapter1.Powered` every two seconds with a bounded D-Bus call, reconciling the icon, status and power toggle after missed shell updates. Queries use the selected adapter path; late replies from a replaced adapter are ignored. Failed queries fall back to the native adapter state.

The installer derives the panel from the installed OS version rather than maintaining a separate upstream copy. An incompatible panel structure stops installation before replacing the working plugin. Apply through `make setup`.
