# Setup user theme folder and seed the default only when no theme exists yet.
mkdir -p ~/.config/kos/themes

if [[ ! -s $HOME/.local/state/kos/current/theme.name ]]; then
  # iso-chroot and provision-owner both run without a live session to notify.
  if [[ ${KOS_SETUP_CONTEXT:-runtime} != "runtime" ]]; then
    KOS_THEME_HEADLESS=1 kos-theme-set "Tokyo Night"
    rm -f ~/.config/chromium/SingletonLock # otherwise archiso owns the Chromium singleton
  else
    kos-theme-set "Tokyo Night"
  fi
fi
kos-theme-set-pi --activate

mkdir -p ~/.config/btop/themes
ln -snf "$HOME/.local/state/kos/current/theme/btop.theme" ~/.config/btop/themes/current.theme
