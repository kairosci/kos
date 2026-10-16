#!/usr/bin/env bash

test_hyprmod() {
    set -euo pipefail
    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
    source "$SCRIPT_DIR/test_lib.sh"
    WORK_DIR=$(mktemp -d)
    trap 'rm -rf -- "$WORK_DIR"' EXIT
    mkdir -p "$WORK_DIR/bin" "$WORK_DIR/home/.config/hypr"
    printf 'local retained = true\n' > "$WORK_DIR/home/.config/hypr/hyprland.lua"
    printf 'local shortcut = true\n' > "$WORK_DIR/home/.config/hypr/bindings.lua"
    printf 'hl.config({ general = { border_size = 3 } })\n' > "$WORK_DIR/home/.config/hypr/hyprland-gui.lua"
    cp "$WORK_DIR/home/.config/hypr/hyprland-gui.lua" "$WORK_DIR/personal.lua"
    cat > "$WORK_DIR/bin/uv" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == venv ]]; then
    directory="${@: -1}"
    mkdir -p "$directory/bin" "$directory/lib/site-packages/hyprmod/data/icons/hicolor/scalable/apps"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$directory/bin/python"
    touch "$directory/lib/site-packages/hyprmod/window.py" "$directory/lib/site-packages/hyprmod/style.css"
    printf '<svg/>\n' > "$directory/lib/site-packages/hyprmod/data/icons/hicolor/scalable/apps/io.github.bluemancz.hyprmod.svg"
    chmod 755 "$directory/bin/python"
else
    while (($#)); do
        if [[ "$1" == --python ]]; then
            directory="${2%/bin/python}"
            printf '#!/usr/bin/env bash\nexit 0\n' > "$directory/bin/hyprmod"
            chmod 755 "$directory/bin/hyprmod"
            break
        fi
        shift
    done
fi
SH
    cat > "$WORK_DIR/bin/pacman" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "$2" in
    python) printf 'python 3.14.7\n' ;;
    python-gobject) printf 'python-gobject 3.56.3\n' ;;
    python-cairo) printf 'python-cairo 1.29.1\n' ;;
    *) exit 1 ;;
esac
SH
    cat > "$WORK_DIR/bin/vercmp" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${HYPRMOD_TEST_OLD:-0}" == 1 ]]; then printf '%s\n' -1; else printf '1\n'; fi
SH
    cat > "$WORK_DIR/bin/Hyprland" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ "${HYPRMOD_TEST_INVALID:-0}" != 1 ]] || exit 1
[[ -f "$OS_HYPR_CONFIG_ROOT/hyprland-gui.lua" ]] || exit 1
printf 'config ok\n'
SH
    printf '#!/usr/bin/env bash\nset -euo pipefail\ncat >/dev/null\n' > "$WORK_DIR/bin/patch"
    chmod 755 "$WORK_DIR/bin/"*
    install_gui() {
        env -i PATH="$WORK_DIR/bin:/usr/bin:/bin" HOME="$WORK_DIR/home" HYPRMOD_TEST_OLD="${HYPRMOD_TEST_OLD:-0}" HYPRMOD_TEST_INVALID="${HYPRMOD_TEST_INVALID:-0}" \
            bash "$PROJECT_DIR/modules/conf/hyprmod/install.sh"
    }
    assert_true "locked application and libraries carry immutable source hashes" "[[ \$(grep -c -- '--hash=sha256:[a-f0-9]\{64\}$' '$PROJECT_DIR/modules/conf/hyprmod/data/requirements.lock') == 6 ]] && grep -q 'archive/[a-f0-9]\{40\}.tar.gz' '$PROJECT_DIR/modules/conf/hyprmod/data/requirements.lock'"
    assert_true "graphical settings preserve existing user overrides" "install_gui && cmp '$WORK_DIR/personal.lua' '$WORK_DIR/home/.config/hypr/hyprland-gui.lua'"
    assert_true "settings include is appended once and survives repeated setup" "install_gui && [[ \$(grep -c '^require(\"hyprland-gui\")$' '$WORK_DIR/home/.config/hypr/hyprland.lua') == 1 ]]"
    assert_true "settings exposes its launcher shortcut and desktop entry" "[[ -x '$WORK_DIR/home/.local/bin/hyprmod' && -f '$WORK_DIR/home/.local/share/applications/io.github.bluemancz.hyprmod.desktop' ]] && grep -q 'SUPER + comma' '$WORK_DIR/home/.config/hypr/bindings.lua'"
    cp "$WORK_DIR/home/.config/hypr/hyprland.lua" "$WORK_DIR/before.lua"
    assert_false "invalid staged compositor configuration prevents installation" "HYPRMOD_TEST_INVALID=1 install_gui"
    assert_true "failed validation leaves the active entrypoint unchanged" "cmp '$WORK_DIR/before.lua' '$WORK_DIR/home/.config/hypr/hyprland.lua'"
    assert_false "an incompatible system GTK runtime is rejected" "HYPRMOD_TEST_OLD=1 install_gui"
    assert_true "interface policy is installed separately from application code" "cmp '$PROJECT_DIR/modules/conf/hyprmod/data/interface.json' '$WORK_DIR/home/.config/hyprmod/interface.json'"
    assert_true "repeated setup never appends duplicate application styles" "[[ \$(grep -c 'window.os-hyprmod .navigation-sidebar row {' '$WORK_DIR/home/.local/share/os/hyprmod/current/lib/site-packages/hyprmod/style.css') == 1 ]]"
    test_summary
}

test_hyprmod "$@"
