# GTK

Setup installs flat GTK styling through the palette hook and native settings through this installer. GTK animations and client window buttons are disabled. Pointer hover, selected rows, text selections, checked controls and suggested actions retain distinct states. Scrollbar sliders preserve nonnegative geometry. Square controls, compact headerbars, outlined keyboard focus and palette selection remain visible in light and dark themes. Headerbars, sidebars, cards and dialogs share the palette background without raised surfaces.

All application windows use opaque, square surfaces without compositor shadows or blur. Windows, layers and popups fade in over 140 ms and fade out over 100 ms with a gradual easing curve. Only these opening and closing opacity transitions animate; focus, dimming, borders and layer geometry update immediately to avoid additional redraws during interaction. Workspace changes, including special workspaces, are immediate to avoid overlapping outgoing and incoming tiles. Window geometry updates immediately, avoiding animated paths that cross neighboring tiles. Tearing is explicitly disabled. Omarchy's application animation exclusions and instant bar and panel layer rules remain authoritative.

The desktop uses the dwindle tiling layout with zero gaps and one pixel borders. Main windows tile; modal dialogs and windows tagged by Omarchy as floating retain their dialog behavior. Keybindings are preserved. GTK keeps application controls and file dialogs functional, with flat palette colors and no client window buttons, gradients or rounded widgets.

Run `make setup` after merging the desktop PRs. Reopen libadwaita applications to load updated CSS. The installer preserves unrelated Hyprland configuration.
