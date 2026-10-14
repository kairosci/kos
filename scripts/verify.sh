#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

source "$SCRIPT_DIR/lib/i18n.sh"
source "$SCRIPT_DIR/lib/target-user.sh"

i18n_init

TARGET_USER=""
TARGET_UID=""
if [[ $EUID -eq 0 ]]; then
    TARGET_USER=$(target_user_resolve || printf '')
    if [[ -n "$TARGET_USER" ]]; then
        TARGET_UID=$(target_uid_resolve "$TARGET_USER" || printf '')
        TARGET_HOME=$(target_home_resolve "$TARGET_USER" || printf '')
        if [[ -n "$TARGET_HOME" ]]; then
            export HOME="$TARGET_HOME"
            export USER="$TARGET_USER"
            export LOGNAME="$TARGET_USER"
        fi
        if [[ -n "$TARGET_UID" && -d "/run/user/$TARGET_UID" ]]; then
            export XDG_RUNTIME_DIR="/run/user/$TARGET_UID"
            export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$TARGET_UID/bus"
        fi
    fi
fi

priv() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
        return
    fi
    sudo -n "$@"
}

can_inspect_system() {
    [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null
}

disk_entry_valid() {
    local disk_entry
    for disk_entry in "/usr/share/omarchy/applications/Disk Usage.desktop" "$HOME/.local/share/applications/Disk Usage.desktop"; do
        [[ ! -f "$disk_entry" ]] || grep -qx Hidden=true "$disk_entry" || return 1
    done
}

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
    local desc="$1" condition="$2"
    if eval "$condition" &>/dev/null; then
        ((PASS++))
        printf '%b\n' "  ${GREEN}$(t verify.label_pass)${NC} $desc"
    else
        ((FAIL++))
        printf '%b\n' "  ${RED}$(t verify.label_fail)${NC} $desc"
    fi
}

section() { printf '%b\n' "\n${BOLD}$(t "$1")${NC}"; }

skip() { printf '%b\n' "  ${RED}$(t verify.label_skip)${NC} $1"; }

tcheck() {
    local key="$1" condition="$2"
    shift 2
    check "$(t "$key" "$@")" "$condition"
}

section verify.sec_packages
tcheck "check.pkg_removed" "! pacman -Q qutebrowser &>/dev/null" qutebrowser
tcheck "check.pkg_removed" "! pacman -Q python-adblock &>/dev/null" python-adblock
for pkg in geany geany-plugins; do
    tcheck "check.pkg_removed" "! pacman -Q $pkg &>/dev/null" "$pkg"
done
tcheck "check.pkg_installed" "pacman -Q brave-origin-bin &>/dev/null" brave-origin-bin
for pkg in zed neovim omarchy-nvim nautilus gvfs papers loupe celluloid baobab resources onlyoffice-bin easyeffects calf lsp-plugins-lv2 mda.lv2 x42-plugins-lv2 zam-plugins-lv2; do
    tcheck "check.pkg_installed" "pacman -Q $pkg &>/dev/null" "$pkg"
done
tcheck "check.pkg_installed" "pacman -Q slack-desktop &>/dev/null" slack-desktop
tcheck "check.pkg_installed" "pacman -Q discord &>/dev/null" discord
tcheck "check.pkg_removed" "! pacman -Q chromium &>/dev/null" chromium
for pkg in tensaku micro imv mupdf btop gdu mpv-mpris libreoffice-still; do
    tcheck "check.pkg_removed" "! pacman -Q $pkg &>/dev/null" "$pkg"
done
tcheck "check.pkg_installed" "pacman -Q fzf &>/dev/null" fzf
tcheck "check.pkg_installed" "pacman -Q universal-ctags &>/dev/null" universal-ctags
tcheck "check.pkg_installed" "pacman -Q shellcheck &>/dev/null" shellcheck
tcheck "check.pkg_installed" "pacman -Q shfmt &>/dev/null" shfmt
tcheck "check.pkg_installed" "pacman -Q ruff &>/dev/null" ruff
tcheck "check.pkg_installed" "pacman -Q yamllint &>/dev/null" yamllint
tcheck "check.pkg_installed" "pacman -Q mpv &>/dev/null" mpv
tcheck "check.pkg_installed" "pacman -Q 7zip &>/dev/null" 7zip
tcheck "check.pkg_installed" "pacman -Q trash-cli &>/dev/null" trash-cli
tcheck "check.pkg_removed" "! pacman -Q zathura &>/dev/null" zathura
tcheck "check.pkg_removed" "! pacman -Q zathura-pdf-mupdf &>/dev/null" zathura-pdf-mupdf
tcheck "check.pkg_removed" "! pacman -Q thunar &>/dev/null" thunar
tcheck "check.pkg_removed" "! pacman -Q yaru-icon-theme &>/dev/null" yaru-icon-theme
tcheck "check.pkg_removed" "! pacman -Q system-config-printer &>/dev/null" system-config-printer
tcheck "check.pkg_removed" "! pacman -Q totem &>/dev/null" totem
tcheck "check.pkg_removed" "! pacman -Q evince &>/dev/null" evince
tcheck "check.pkg_removed" "! pacman -Q eog &>/dev/null" eog
tcheck "check.pkg_removed" "! pacman -Q dolphin &>/dev/null" dolphin
tcheck "check.pkg_removed" "! pacman -Q okular &>/dev/null" okular
tcheck "check.pkg_removed" "! pacman -Q gwenview &>/dev/null" gwenview
tcheck "check.pkg_removed" "! pacman -Q kdenlive &>/dev/null" kdenlive
tcheck "check.daemon_absent" "! command -v dockerd &>/dev/null" dockerd
tcheck "check.runtime_present" "pacman -Q podman &>/dev/null" podman
tcheck "check.pkg_removed" "! pacman -Q obs-studio &>/dev/null" obs-studio
tcheck "check.pkg_removed" "! pacman -Q libreoffice-fresh &>/dev/null" libreoffice-fresh
tcheck "check.pkg_removed" "! pacman -Q obsidian &>/dev/null" obsidian
tcheck "check.pkg_installed" "pacman -Q capitaine-cursors &>/dev/null" capitaine-cursors
tcheck "check.pkg_installed" "pacman -Q qogir-icon-theme &>/dev/null" qogir-icon-theme
tcheck "check.pkg_removed" "! pacman -Q gnome-disk-utility &>/dev/null" gnome-disk-utility
tcheck "check.pkg_removed" "! pacman -Q dua-cli &>/dev/null" dua-cli
tcheck "check.pkg_removed" "! pacman -Q gnome-themes-extra &>/dev/null" gnome-themes-extra

section verify.sec_gui
tcheck "check.tool_present" "pacman -Q herdr &>/dev/null" herdr
tcheck "check.tool_present" "pacman -Q gum &>/dev/null" gum

section verify.sec_browser
tcheck "check.default_browser" "[[ \"\$(env -u BROWSER xdg-settings get default-web-browser 2>/dev/null)\" == brave-origin.desktop ]]"
tcheck "check.default_editor"  "[[ \"\$(cat \$HOME/.local/state/omarchy/defaults/editor 2>/dev/null)\" == zed ]]"
tcheck "check.default_editor" "[[ \"\$(xdg-mime query default text/plain)\" == dev.zed.Zed.desktop ]]"
section verify.sec_firewall
if UFW_STATUS=$(priv ufw status 2>/dev/null); then
    tcheck "check.ufw_active"          "echo '$UFW_STATUS' | grep -q 'Status: active'"
    tcheck "check.ufw_deny_incoming"       "priv ufw status verbose 2>/dev/null | grep -q 'Default: deny (incoming)'"
    tcheck "check.ufw_allow_outgoing"      "priv ufw status verbose 2>/dev/null | grep -q 'allow (outgoing)'"
else
    skip "$(t verify.skip_root)"
fi
if can_inspect_system; then
    tcheck "check.ufw_boot" "priv systemctl is-enabled ufw.service &>/dev/null"
else
    skip "$(t verify.skip_root)"
fi

section verify.sec_kernel
if can_inspect_system; then
for setting in \
    "kernel.randomize_va_space	2" \
    "kernel.kptr_restrict	2" \
    "kernel.dmesg_restrict	1" \
    "kernel.perf_event_paranoid	3" \
    "kernel.unprivileged_bpf_disabled	1" \
    "kernel.yama.ptrace_scope	1" \
    "kernel.sysrq	16" \
    "fs.suid_dumpable	0" \
    "fs.protected_hardlinks	1" \
    "fs.protected_symlinks	1" \
    "fs.protected_fifos	2" \
    "fs.protected_regular	2" \
    "net.ipv4.conf.all.rp_filter	1" \
    "net.ipv4.conf.all.accept_redirects	0" \
    "net.ipv4.conf.all.send_redirects	0" \
    "net.ipv4.conf.all.accept_source_route	0" \
    "net.ipv4.icmp_echo_ignore_broadcasts	1" \
    "net.ipv4.tcp_syncookies	1" \
    "net.ipv4.tcp_rfc1337	1" \
    ; do
    key="${setting%%	*}"
    expected="${setting##*	}"
    check "$key = $expected" "[[ \"\$(priv sysctl -n $key 2>/dev/null)\" == $expected ]]"
done
else
    skip "$(t verify.skip_root)"
fi
tcheck "check.sysctl_persisted"         "[[ -f /etc/sysctl.d/99-security.conf ]]"
tcheck "check.coredump_disabled"             "[[ -f /etc/security/limits.d/99-no-core.conf ]]"

section verify.sec_pam
tcheck "check.faillock"    "[[ -f /etc/security/faillock.conf ]] && grep -q '^[^#].*pam_faillock.so' /etc/pam.d/system-auth && ! grep -Eq '^[^#].*pam_faillock.so.*(deny|unlock_time|conf)=' /etc/pam.d/system-auth"
tcheck "check.pwquality"   "[[ -f /etc/security/pwquality.conf ]] && grep -Eq '^password[[:space:]]+requisite[[:space:]]+pam_pwquality.so' /etc/pam.d/system-auth && grep -Eq '^password.*pam_unix.so.*use_authtok' /etc/pam.d/system-auth"
tcheck "check.access_conf" "[[ -f /etc/security/access.conf ]] && grep -q 'ALL:ALL' /etc/security/access.conf"

section verify.sec_ssh
SSHD_DIR="/etc/ssh/sshd_config.d"
if [[ -r "$SSHD_DIR/hardened.conf" ]]; then
    tcheck "check.sshd_hardened"        "[[ -f $SSHD_DIR/hardened.conf ]]"
    tcheck "check.sshd_root_login"     "grep -q '^PermitRootLogin no' $SSHD_DIR/hardened.conf"
    tcheck "check.sshd_password_auth"  "grep -q '^PasswordAuthentication no' $SSHD_DIR/hardened.conf"
elif priv test -r "$SSHD_DIR/hardened.conf" 2>/dev/null; then
    tcheck "check.sshd_hardened"        "priv test -f $SSHD_DIR/hardened.conf"
    tcheck "check.sshd_root_login"     "priv grep -q '^PermitRootLogin no' $SSHD_DIR/hardened.conf"
    tcheck "check.sshd_password_auth"  "priv grep -q '^PasswordAuthentication no' $SSHD_DIR/hardened.conf"
else
    skip "$(t verify.skip_ssh)"
fi

section verify.sec_services
if can_inspect_system; then
    tcheck "check.avahi_disabled" "! priv systemctl is-enabled avahi-daemon.service 2>/dev/null | grep -q '^enabled$'"
    tcheck "check.cups_disabled" "! priv systemctl is-enabled cups.service 2>/dev/null | grep -q '^enabled$'"
else
    skip "$(t verify.skip_root)"
fi
tcheck "check.sshd_service_hardened"   "[[ -f /etc/systemd/system/sshd.service.d/hardened.conf ]]"
tcheck "check.networkmanager_intact" "! [[ -f /etc/NetworkManager/conf.d/security.conf ]]"
tcheck "check.resolved_hardened" "[[ -f /etc/systemd/resolved.conf.d/hardened.conf ]]"

section verify.sec_tooling
for pkg in lynis rkhunter clamav audit usbguard fail2ban apparmor; do
    check "$pkg present" "pacman -Q $pkg &>/dev/null"
done
tcheck "check.apparmor_kernel" "grep -Eq '(^| )lsm=[^ ]*apparmor[^ ]*( |$)' /proc/cmdline && [[ -r /sys/kernel/security/apparmor/profiles ]]"

section verify.sec_perms
tcheck "check.perm_root"       "[[ \"\$(stat -c %a /root)\" == 700 ]]"
tcheck "check.perm_shadow" "[[ \"\$(stat -c %a /etc/shadow)\" == 600 ]]"
tcheck "check.perm_gshadow" "[[ \"\$(stat -c %a /etc/gshadow)\" == 600 ]]"
tcheck "check.perm_passwd" "[[ \"\$(stat -c %a /etc/passwd)\" == 644 ]]"
tcheck "check.perm_group"  "[[ \"\$(stat -c %a /etc/group)\" == 644 ]]"

section verify.sec_modules
tcheck "check.usb_storage_blocked"      "[[ -f /etc/modprobe.d/disable-usb-storage.conf ]]"
tcheck "check.protocols_blocked" "[[ -f /etc/modprobe.d/disable-protocols.conf ]]"
tcheck "check.firewire_blocked"         "[[ -f /etc/modprobe.d/disable-firewire.conf ]]"
tcheck "check.filesystems_blocked" "[[ -f /etc/modprobe.d/disable-ramfs.conf ]]"

section verify.sec_health
tcheck "check.tpm_verity_removed" "! [[ -f /usr/lib/nvpcr/verity.nvpcr ]]"
tcheck "check.voxtype_inactive" "! systemctl --user is-active voxtype 2>/dev/null | grep -q '^active$'"
tcheck "check.kitty_terminal" "pacman -Q kitty &>/dev/null && ! pacman -Q foot &>/dev/null"
tcheck "check.webapps_removed" "! grep -rlE 'omarchy-(launch-webapp|webapp-handler)' /usr/share/omarchy/applications 2>/dev/null"

section verify.sec_power
if compgen -G '/sys/class/leds/*kbd_backlight*' >/dev/null; then
    tcheck "check.keyboard_policy" "[[ -x /usr/local/libexec/os-keyboard-backlight && -f /etc/systemd/system/os-keyboard-backlight@.service && -f /etc/udev/rules.d/99-os-keyboard-backlight.rules ]] && systemctl is-enabled --quiet os-keyboard-backlight.service && systemctl is-enabled --quiet os-keyboard-backlight.timer && systemctl is-active --quiet os-keyboard-backlight.timer"
    tcheck "check.keyboard_maximum" "bash '$SCRIPT_DIR/lib/keyboard-backlight.sh' --check"
else
    skip "$(t power.keyboard_unsupported)"
fi
tcheck "check.power_conf" "[[ -f /etc/os/power.conf ]]"
tcheck "check.battery_udev" "[[ -f /etc/udev/rules.d/98-battery-charge-threshold.rules ]]"
tcheck "check.battery_tmpfiles" "[[ -f /etc/tmpfiles.d/battery-charge-threshold.conf ]]"
tcheck "check.battery_service" "systemctl is-enabled battery-charge-threshold.service &>/dev/null || [[ -L /etc/systemd/system/multi-user.target.wants/battery-charge-threshold.service ]]"
tcheck "check.battery_service" "systemctl is-enabled --quiet battery-charge-threshold.timer && systemctl is-active --quiet battery-charge-threshold.timer"
BATTERY_HELPER=/usr/local/libexec/os-set-battery-charge-limit
BATTERY_STATE_LIMIT=""
BATTERY_FUNCTIONAL=""
BATTERY_DRIFT=""
if [[ -x "$BATTERY_HELPER" ]]; then
    BATTERY_STATE_LIMIT=$("$BATTERY_HELPER" --query state_limit 2>/dev/null) || BATTERY_STATE_LIMIT=""
    BATTERY_FUNCTIONAL=$("$BATTERY_HELPER" --query functional_nodes 2>/dev/null) || BATTERY_FUNCTIONAL=""
    BATTERY_DRIFT=$("$BATTERY_HELPER" --query drift 2>/dev/null) || BATTERY_DRIFT=""
fi
BATTERY_POLICY=$(sed -n 's/^BATTERY_CHARGE_LIMIT=\([0-9][0-9]*\)$/\1/p' /etc/os/power.conf 2>/dev/null | head -1)
BATTERY_POLICY=${BATTERY_POLICY:-75}

if [[ -n "$BATTERY_STATE_LIMIT" && -n "$BATTERY_FUNCTIONAL" && -n "$BATTERY_DRIFT" ]]; then
    tcheck "check.battery_policy_applied" "[[ '$BATTERY_STATE_LIMIT' == '$BATTERY_POLICY' ]]"
    if [[ "$BATTERY_FUNCTIONAL" == "0" && "$BATTERY_DRIFT" == "no" ]]; then
        skip "$(t verify.skip_charge_unsupported)"
    elif [[ "$BATTERY_DRIFT" == "no" ]]; then
        check "$(t check.battery_limit)" true
    else
        check "$(t check.battery_limit)" false
    fi
else
    check "$(t verify.skip_charge_state)" false
fi
if [[ -r /sys/power/mem_sleep ]]; then
    if grep -q '\[deep\]' /sys/power/mem_sleep; then
        tcheck "check.suspend_conf" "grep -q '^MemorySleepMode=deep$' /etc/systemd/sleep.conf.d/99-os-suspend.conf"
    elif grep -q '\[s2idle\]' /sys/power/mem_sleep; then
        tcheck "check.suspend_conf" "grep -q '^MemorySleepMode=s2idle$' /etc/systemd/sleep.conf.d/99-os-suspend.conf"
    else
        tcheck "check.suspend_conf" "[[ -f /etc/systemd/sleep.conf.d/99-os-suspend.conf ]]"
    fi
fi

section verify.sec_sched
tcheck "check.weekly_audit" "{ systemctl is-enabled --quiet os-security-audit.timer && systemctl is-active --quiet os-security-audit.timer; } || { systemctl is-enabled --quiet cronie.service && systemctl is-active --quiet cronie.service; }"
if [[ -r /etc/cron.weekly/security-audit.sh ]]; then
    tcheck "check.weekly_audit" "[[ -f /etc/cron.weekly/security-audit.sh && -x /etc/cron.weekly/security-audit.sh ]]"
elif priv test -r /etc/cron.weekly/security-audit.sh 2>/dev/null; then
    tcheck "check.weekly_audit" "priv test -f /etc/cron.weekly/security-audit.sh && priv test -x /etc/cron.weekly/security-audit.sh"
else
    skip "$(t verify.skip_audit)"
fi

section verify.sec_userconfigs
tcheck "check.starship_config"  "[[ -f \$HOME/.config/starship.toml ]]"
tcheck "check.git_config"       "[[ -f \$HOME/.config/git/config ]]"
tcheck "check.lazygit_config"   "[[ -f \$HOME/.config/lazygit/config.yml ]]"
tcheck "check.portals_conf"     "[[ -f \$HOME/.config/xdg-desktop-portal/portals.conf ]] && grep -q 'FileChooser=gtk' \$HOME/.config/xdg-desktop-portal/portals.conf"
tcheck "check.keyring_pam" "grep -Eq '^session[[:space:]]+optional[[:space:]]+pam_gnome_keyring.so.*auto_start' /etc/pam.d/login"
tcheck "check.keyring_backend" "grep -qx gnome-keyring /etc/os/keyring-backend"
tcheck "check.keyring_provider" "pacman -Q gnome-keyring seahorse &>/dev/null && ! pacman -Q keepassxc &>/dev/null"
tcheck "check.desktop_graphical" "pacman -Q nautilus gvfs xdg-desktop-portal-gtk &>/dev/null && [[ \"\$(xdg-mime query default inode/directory)\" == org.gnome.Nautilus.desktop ]]"
tcheck "check.cli_secrets"      "command -v secret-tool &>/dev/null && command -v pass &>/dev/null"
tcheck "check.onlyoffice_config" "[[ -f \$HOME/.config/onlyoffice/DesktopEditors.conf ]]"
tcheck "check.onlyoffice_default" "[[ \$(xdg-mime query default application/vnd.openxmlformats-officedocument.wordprocessingml.document) == onlyoffice-desktopeditors.desktop ]]"
tcheck "check.mpv_hidden" "grep -qx Hidden=true \"\$HOME/.local/share/applications/mpv.desktop\""
source "$SCRIPT_DIR/lib/desktop-cleanup.sh"
tcheck "check.desktop_unique" "desktop_cleanup_unique \"\$HOME\""

section verify.sec_debloat
source "$SCRIPT_DIR/lib/package-pins.sh"
tcheck "check.retained_updateable" "package_pins_retained_updateable"
tcheck "check.ignorepkg" "! grep -q '^[[:space:]]*IgnorePkg[[:space:]]*=' /etc/pacman.conf"
tcheck "check.icon_theme"      "gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | grep -q 'Qogir'"
tcheck "check.cursor_theme"  "gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | grep -q 'capitaine-cursors'"
tcheck "check.no_tela"         "! grep -rq 'Tela' $HOME/.config/omarchy/themes/ 2>/dev/null"
tcheck "check.folder_color_hook"        "[[ -x $HOME/.config/omarchy/hooks/theme-set.d/folder-color ]]"

section verify.sec_desktop
tcheck "check.desktop_no_foot" "pacman -Q foot &>/dev/null || [[ ! -f \"/usr/share/omarchy/applications/foot.desktop\" ]]"
tcheck "check.desktop_disk_valid" "disk_entry_valid"
tcheck "check.desktop_no_docker" "command -v lazydocker &>/dev/null || [[ ! -f \"/usr/share/omarchy/applications/Docker.desktop\" ]]"
tcheck "check.desktop_hook" "[[ -f /etc/pacman.d/hooks/99-os-desktop-cleanup.hook ]] && [[ -x /usr/local/libexec/os-desktop-cleanup ]]"

section verify.sec_performance
# shellcheck source=scripts/lib/responsiveness.sh
source "$SCRIPT_DIR/lib/responsiveness.sh"
tcheck "check.performance_files" "responsiveness_files_match \"$(dirname "$SCRIPT_DIR")\""
tcheck "check.performance_runtime" "responsiveness_runtime \"$(dirname "$SCRIPT_DIR")\""

section verify.sec_aur
tcheck "check.no_unverified_aur" "! grep -q 'aur_install ' '$SCRIPT_DIR/setup.sh'"
tcheck "check.no_yay"   "! grep -q 'yay -S' '$SCRIPT_DIR/setup.sh'"

section verify.sec_locale
VERIFY_LANG=$(sed -n 's/^LANG=//p' /etc/locale.conf 2>/dev/null | head -1)

locale_generated() {
    local want have
    want=$(printf '%s' "$VERIFY_LANG" | tr '[:upper:]' '[:lower:]' | tr -d '-')
    have=$(locale -a 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '-')
    [[ -n "$want" ]] && grep -qxF "$want" <<< "$have"
}
tcheck "verify.locale_conf"  "[[ -f /etc/locale.conf ]]"
tcheck "verify.locale_lang"  "[[ -n \"$VERIFY_LANG\" ]]"
tcheck "verify.locale_keymap" "grep -qE '^KEYMAP=' /etc/vconsole.conf 2>/dev/null"
tcheck "verify.locale_generated" "locale_generated"
tcheck "verify.locale_profile" "[[ -f /etc/profile.d/os-locale.sh ]]"
tcheck "verify.locale_hyprland" "grep -rq 'kb_layout' /home/*/.config/hypr/input.lua 2>/dev/null"
catalog_check() {
    local lang
    for lang in en it fr de es pt; do
        [[ -f "$SCRIPT_DIR/lib/messages/$lang.msg" ]] || return 1
    done
    return 0
}
tcheck "verify.locale_catalogs" "catalog_check"
tcheck "verify.locale_i18n" "[[ -n \"$I18N_LANG\" ]] && (( ${#OS_I18N[@]} > 0 ))"

printf '\n'
printf '%s\n' "$(t verify.tests_executed "$((PASS + FAIL))")"
printf '%b\n' "${BOLD}$(t verify.passed_summary "$PASS" "$FAIL")${NC}"
[[ $FAIL -eq 0 ]] || exit 1
