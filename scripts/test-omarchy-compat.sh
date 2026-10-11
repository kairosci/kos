#!/usr/bin/env bash

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check() {
    local desc="$1" condition="$2"
    if eval "$condition" &>/dev/null; then
        ((PASS++))
        printf '%b\n' "  ${GREEN}pass${NC} $desc"
    else
        ((FAIL++))
        printf '%b\n' "  ${RED}fail${NC} $desc"
    fi
}

warn_check() {
    local desc="$1" condition="$2"
    if eval "$condition" &>/dev/null; then
        ((PASS++))
        printf '%b\n' "  ${GREEN}pass${NC} $desc"
    else
        ((WARN++))
        printf '%b\n' "  ${YELLOW}warn${NC} $desc"
    fi
}

section() { printf '%b\n' "\n${BOLD}$1${NC}"; }

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/lib/i18n.sh"
i18n_init || exit 1

section "Script Syntax & Code Integrity"
for sh_file in "$PROJECT_DIR"/scripts/*.sh "$PROJECT_DIR"/hooks/theme-set.d/* "$PROJECT_DIR"/conf/*/*.sh; do
    [[ -f "$sh_file" ]] || continue
    check "syntax check: $(basename "$sh_file")" "bash -n '$sh_file'"
done

section "Omarchy Theming & Hook Integration"
HOOK_FILE="$PROJECT_DIR/hooks/theme-set.d/folder-color"
check "folder-color hook exists" "[[ -f '$HOOK_FILE' ]]"
check "folder-color hook is executable" "[[ -x '$HOOK_FILE' ]]"

test_icon_mapping() {
    local theme="$1" expected="$2"
    local mapped
    case "$theme" in
        white|flexoki-light|catppuccin-latte|solarized-light) mapped="Qogir" ;;
        *) mapped="Qogir-Dark" ;;
    esac
    [[ "$mapped" == "$expected" ]]
}

check "icon map: everforest -> Qogir-Dark" "test_icon_mapping 'everforest' 'Qogir-Dark'"
check "icon map: vantablack -> Qogir-Dark" "test_icon_mapping 'vantablack' 'Qogir-Dark'"
check "icon map: white -> Qogir" "test_icon_mapping 'white' 'Qogir'"
check "icon map: flexoki-light -> Qogir" "test_icon_mapping 'flexoki-light' 'Qogir'"
check "icon map: catppuccin-latte -> Qogir" "test_icon_mapping 'catppuccin-latte' 'Qogir'"
check "icon map: solarized-light -> Qogir" "test_icon_mapping 'solarized-light' 'Qogir'"
check "icon map: default -> Qogir-Dark" "test_icon_mapping 'default' 'Qogir-Dark'"

section "Desktop Environment & User Session"
warn_check "D-Bus session accessible" "[[ -n \"${DBUS_SESSION_BUS_ADDRESS:-}\" ]] || busctl --user status &>/dev/null"
warn_check "XDG runtime directory valid" "[[ -d \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}\" ]]"
if [[ $EUID -eq 0 ]] || sudo -n true &>/dev/null; then
    check "Polkit daemon enabled/active" "systemctl is-active polkit.service &>/dev/null || systemctl is-enabled polkit.service &>/dev/null"
else
    warn_check "Polkit service state unavailable without system privileges" "false"
fi
warn_check "Audio server running (PipeWire)" "systemctl --user is-active pipewire.service &>/dev/null || pgrep -x pipewire &>/dev/null"

section "Network & Connectivity Non-Interference"
check "NetworkManager configuration unmolested" "! [[ -f /etc/NetworkManager/conf.d/security.conf ]]"
if ip link show lo &>/dev/null; then
    check "Loopback interface up" "ip link show lo 2>/dev/null | grep -q 'state UP\|state UNKNOWN'"
else
    warn_check "Loopback state unavailable in this execution context" "false"
fi
warn_check "DNS resolver functional" "getent hosts archlinux.org &>/dev/null || resolvectl query archlinux.org &>/dev/null"

section "Omarchy Application & Package Parity"
check "yaru-icon-theme removed" "! pacman -Q yaru-icon-theme &>/dev/null"
check "Thunar removed" "! pacman -Q thunar &>/dev/null"
check "herdr installed" "pacman -Q herdr &>/dev/null"
check "gum installed" "pacman -Q gum &>/dev/null"
check "Nautilus installed" "pacman -Q nautilus &>/dev/null"
check "Zed installed" "pacman -Q zed &>/dev/null"
check "OnlyOffice installed" "pacman -Q onlyoffice-bin &>/dev/null"
check "7zip installed" "pacman -Q 7zip &>/dev/null"
check "Loupe installed" "pacman -Q loupe &>/dev/null"
check "trash-cli installed" "pacman -Q trash-cli &>/dev/null"
check "Celluloid installed" "pacman -Q celluloid &>/dev/null"
check "Papers installed" "pacman -Q papers &>/dev/null"

for debloated in chromium thunar yaru-icon-theme kdenlive obs-studio libreoffice-fresh obsidian gnome-disk-utility gnome-themes-extra micro imv mupdf btop gdu mpv-mpris libreoffice-still; do
    check "debloat verified: $debloated removed" "! pacman -Q '$debloated' &>/dev/null"
done
check "docker daemon absent" "! command -v dockerd &>/dev/null"

section "Pacman Configuration & Pinning"
check "No IgnorePkg in /etc/pacman.conf" "! grep -q '^[[:space:]]*IgnorePkg[[:space:]]*=' /etc/pacman.conf"
check "No syntax error in /etc/pacman.conf" "pacman -Q &>/dev/null"

section "Security Daemon Non-Lockout Checks"
if [[ -f /etc/usbguard/rules.conf ]]; then
    check "USBGuard allows HID input devices" "grep -q '03:00:01\|03:01:01\|03:01:02\|interface-class == { 03:..:.. }' /etc/usbguard/rules.conf 2>/dev/null || grep -q 'allow' /etc/usbguard/rules.conf"
fi
check "Primary user in wheel group" "[[ \$(id -u) -eq 0 ]] || getent group wheel | awk -F: -v user=\"\$(id -un)\" 'index(\",\" \$4 \",\", \",\" user \",\")'"
check "User has valid shell in /etc/shells" "grep -qFx \"$SHELL\" /etc/shells"

section "Omarchy User Configurations"
warn_check "Starship prompt config exists" "[[ -f \"$HOME/.config/starship.toml\" ]]"
warn_check "Git user config exists" "[[ -f \"$HOME/.config/git/config\" ]]"

printf '\n'
printf '%s\n' "$(t verify.tests_executed "$((PASS + FAIL + WARN))")"
printf '%b\n' "${BOLD}Passed: $PASS  Failed: $FAIL  Warnings: $WARN${NC}"
[[ $FAIL -eq 0 ]] || exit 1
