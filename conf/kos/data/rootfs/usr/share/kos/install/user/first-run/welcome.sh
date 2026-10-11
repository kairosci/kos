# Real newlines, not a literal \n: the card renders the body as it arrives, and
# elides past three lines.
kos-notification-send -u critical -g  "Learn Keybindings" \
  $'Super + K for cheatsheet.\nSuper + Space for Kos Menu.' \
  --exec kos-menu-keybindings
