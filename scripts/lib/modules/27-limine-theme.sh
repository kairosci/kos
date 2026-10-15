#!/usr/bin/env bash

set -euo pipefail

log "limine.theme"
install -Dm644 "$PROJECT_ROOT/modules/iso/assets/limine-wallpaper.png" /usr/share/os/limine/wallpaper.png
install -Dm755 "$PROJECT_ROOT/scripts/lib/limine-theme.sh" /usr/local/libexec/os-limine-theme
install -d -m 755 /etc/boot/hooks/post.d
cat > /etc/boot/hooks/post.d/85-os-limine-theme << 'HOOK'
#!/usr/bin/env bash
set -euo pipefail
/usr/local/libexec/os-limine-theme
HOOK
chmod 755 /etc/boot/hooks/post.d/85-os-limine-theme
/usr/local/libexec/os-limine-theme
