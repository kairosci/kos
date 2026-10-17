# Settings

[Italiano](../it/settings.md) · [English](settings.md) · [Français](../fr/settings.md)

`os app settings`, also available through Super and comma, opens one tiling application containing Hyprland desktop, network, Bluetooth, audio and power. It appears in Apps without a Desktop tools entry. Historical `os app network`, `os app bluetooth` and `os app audio` roles open the same application.

Desktop controls read current compositor values and expose 26 preferences, including borders, rounding, pointer sensitivity, key repeat, animations, blur and its size and passes, shadows, opacity, touchpad behavior, screen wake, window layout and keyboard layout. Changes are validated against a configuration copy before publishing the managed `hypr/os-settings.lua` module. Private JSON stores state; personal files remain preserved. Failed reload restores the previous module. Writes are serialized and errors remain visible. Advanced HyprMod controls are not all implemented; HyprMod remains installed.

The network page uses Quickshell's native NetworkManager integration for Ethernet, Wi-Fi, connection, disconnection, profile removal and personal WPA passwords. Secrets go directly to the service API, never process arguments or catalogs. VPN, manual IP settings and enterprise authentication are not editable here; existing profiles remain preserved.

Bluetooth uses BlueZ for adapter power, discovery, pairing and connection. PIN requests still depend on the existing agent. Audio uses PipeWire for default devices, volume and mute. Real Wi-Fi connections, Bluetooth pairing and audio behavior require hardware checks beyond isolated interface tests.

Power reads the battery through UPower and edits lock and screensaver delays. Lua atomically saves native session JSON while preserving unrelated preferences and the single idle scheduler. Charging thresholds remain owned by the hardware power policy.

Lua algorithms live in `src/component/settings/`, policy and metadata in `data/component/settings/`, native controls in `src/component/settings/qml/`, and the essential launcher in `script/os-settings`. Shared immutable runtime packaging belongs to `src/core/bundle.lua`. Provision through `make setup SCOPE=settings`; user GUI changes are saved through native services and the Lua backend.

References: [Quickshell Networking](https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/Networking/), [Wi-Fi credentials](https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/WifiNetwork/).
