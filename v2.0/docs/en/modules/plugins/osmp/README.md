# OSMP

OSMP 1.5.0 is OS's media control plugin for the native Omarchy shell. Its identifier is `os.osmp`. It uses the shell's shared colors, typography, buttons, popup cards and sliders, so it follows the active desktop theme.

## Installation and updates

Run `make setup` from the root repository. The pipeline installs the canonical local sources, preserves existing widget enablement and archives any previous `krosci.omamp` installation under `~/.local/state/os/retired-plugins/`. Repeated setup reconciles the installed files without downloading a separate plugin repository. Personal changes to replaced files are backed up by the shared configuration installer.

## Playback behavior

Playing media shows a pause icon. Loaded, paused media remains visible with a play icon. Stopped players and empty sessions collapse completely; the popup closes when media disappears. Track titles remain static and elide on the right.

Left click opens the media panel; right click toggles playback; middle click advances to the next track. Scrolling selects previous or next tracks. Controls are available only when supported by the player. Seeking requires a seekable track with a known duration and stays within its boundaries. Muting restores the previous volume when toggled again. Controls follow native shell corner geometry and secondary labels preserve contrast in both light and dark themes. Queue selection uses track identifiers to distinguish repeated titles.

The panel includes album artwork, normalized metadata, progress, playback controls, an optional native MPRIS queue, session history and source selection. Missing artwork uses the shell's media glyph. History stays in memory and is not saved to disk. MPRIS track durations are converted from microseconds, including tracks shorter than one second.

Playback uses Quickshell's MPRIS service. Optional TrackList requests use argument arrays with `busctl`; media metadata is never evaluated as shell code. Switching players cancels pending queue requests and clears the previous queue.

## Development checks

Run `npm test --prefix src/component/media/osmp` from the root repository. Run `make lint` and `make test` for provisioning changes. Apply runtime changes only through `make setup`; inspect the native shell plugin list and journal afterwards.

The plugin uses the MIT license. See [LICENSE](LICENSE).
