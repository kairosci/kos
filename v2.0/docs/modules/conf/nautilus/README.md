# Nautilus

Nautilus is the directory handler. The installer uses native GSettings for a compact list with name, size and modification date, folders first, alphabetical sorting, double click and a breadcrumb path bar. Hidden files stay hidden; thumbnails and recursive searches are limited to local files. The shared GTK hook supplies the active palette and Qogir icons.

Unrelated preferences, bookmarks and folder metadata are preserved. Open projects with `zed --new /path/to/project`. Setup installs Nautilus and GVFS without the GNOME desktop and retires Thunar while preserving personal configuration.

The GTK 4 palette hook styles Nautilus's native places sidebar with consistent row spacing, muted inactive icons, an accent marker for the selected location and compact eject buttons. It preserves bookmarks, locations and the responsive sidebar width. Reopen Nautilus after setup to load the updated GTK CSS.
