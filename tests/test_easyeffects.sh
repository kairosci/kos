#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/test_lib.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home" XDG_CONFIG_HOME="$SANDBOX/config" XDG_DATA_HOME="$SANDBOX/data" XDG_STATE_HOME="$SANDBOX/state" XDG_RUNTIME_DIR="$SANDBOX/runtime" OS_LANG=en
mkdir -p "$SANDBOX/bin" "$XDG_CONFIG_HOME/easyeffects/db" "$XDG_DATA_HOME/easyeffects/output"
printf '[StreamInputs]\nplugins=personal-input\n[StreamOutputs]\noutputDevice=personal-device\n' > "$XDG_CONFIG_HOME/easyeffects/db/easyeffectsrc"
printf '{"personal":true}\n' > "$XDG_DATA_HOME/easyeffects/output/Personal.json"
cat > "$SANDBOX/bin/pacman" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ ${MOCK_MISSING_PACKAGE:-} != "$2" ]]
MOCK
chmod 755 "$SANDBOX/bin/pacman"
export PATH="$SANDBOX/bin:$PATH"
INSTALLER="$PROJECT_DIR/conf/easyeffects/install.sh"
PRESET="$XDG_DATA_HOME/easyeffects/output/OS-Subwoofer.json"

test_section "EasyEffects Bass Preset"
assert_true "EasyEffects module installs without a live session" "bash '$INSTALLER'"
assert_true "bass preset boosts limited output while reserving headroom" "jq -e '.output.plugins_order[-1] == \"limiter#0\" and .output[\"filter#0\"][\"input-gain\"] <= -6 and .output[\"limiter#0\"].bypass == false and .output[\"limiter#0\"][\"threshold\"] <= -2 and .output[\"limiter#0\"][\"gain-boost\"] == true and .output[\"limiter#0\"].alr == false' '$PRESET'"
assert_true "preset affects output only with an internal sidechain" "jq -e 'has(\"input\") == false and .output[\"limiter#0\"][\"sidechain-type\"] == \"Internal\"' '$PRESET'"
assert_true "preset limits low frequency energy" "jq -e '.output[\"filter#0\"].type == \"High-pass\" and .output[\"filter#0\"].frequency >= 60 and .output[\"bass_enhancer#0\"][\"floor-active\"] == true' '$PRESET'"
assert_file_contains_literal "personal preset survives installation" "$XDG_DATA_HOME/easyeffects/output/Personal.json" '"personal":true'
assert_file_contains_literal "installer preserves the input pipeline" "$XDG_CONFIG_HOME/easyeffects/db/easyeffectsrc" 'plugins=personal-input'
assert_file_contains_literal "installer preserves the output device" "$XDG_CONFIG_HOME/easyeffects/db/easyeffectsrc" 'outputDevice=personal-device'
assert_true "database backup is private" "[[ \$(stat -c %a '$XDG_STATE_HOME/os/easyeffects/before-setup/easyeffectsrc') == 600 ]]"
assert_false "offline installation does not claim activation" "[[ -e '$XDG_STATE_HOME/os/easyeffects/default-applied' ]]"
before=$(sha256sum "$PRESET" "$XDG_STATE_HOME/os/easyeffects/before-setup/easyeffectsrc")
printf '\npersonal-change=true\n' >> "$XDG_CONFIG_HOME/easyeffects/db/easyeffectsrc"
assert_true "reinstallation preserves the original recovery snapshot" "bash '$INSTALLER'; [[ \"\$(sha256sum '$PRESET' '$XDG_STATE_HOME/os/easyeffects/before-setup/easyeffectsrc')\" == '$before' ]]"
assert_false "missing plugins stop setup" "MOCK_MISSING_PACKAGE=calf bash '$INSTALLER'"
if command -v desktop-file-validate >/dev/null; then
    assert_true "native autostart entry is valid" "desktop-file-validate '$XDG_CONFIG_HOME/autostart/com.github.wwmm.easyeffects.desktop'"
fi
cat > "$SANDBOX/bin/easyeffects" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_EASYEFFECTS_COMMANDS"
case "$1" in
    --last-loaded-preset)
        if [[ -f "$MOCK_EASYEFFECTS_LOADED" ]]; then
            [[ ${MOCK_QUERY_FAIL:-0} == 0 ]] || exit 1
            printf '%s\n' OS-Subwoofer
        else
            printf '%s\n' "${MOCK_PREVIOUS_PRESET:-}"
        fi
        ;;
    --load-preset)
        [[ ${MOCK_LOAD_FAIL:-0} == 0 ]] || exit 1
        : > "$MOCK_EASYEFFECTS_LOADED"
        ;;
    --bypass) [[ "$2" == 1 ]] ;;
    *) exit 1 ;;
esac
MOCK
chmod 755 "$SANDBOX/bin/easyeffects"
export MOCK_EASYEFFECTS_COMMANDS="$SANDBOX/native-commands" MOCK_EASYEFFECTS_LOADED="$SANDBOX/loaded"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
source "$PROJECT_DIR/conf/easyeffects/apply.sh"
i18n_init
PRESET=OS-Subwoofer
STATE="$SANDBOX/activation"
assert_false "load failures propagate" "(MOCK_LOAD_FAIL=1 easyeffects_apply_preset)"
assert_file_contains_literal "failed load activates safe bypass" "$MOCK_EASYEFFECTS_COMMANDS" '--bypass 1'
assert_false "failed activation does not write its success marker" "[[ -e '$STATE/default-applied' ]]"
: > "$MOCK_EASYEFFECTS_COMMANDS"
assert_false "post-load query failures propagate" "(MOCK_QUERY_FAIL=1 easyeffects_apply_preset)"
assert_file_contains_literal "post-load query failures also activate bypass" "$MOCK_EASYEFFECTS_COMMANDS" '--bypass 1'
assert_true "native activation records verified success" "easyeffects_apply_preset && [[ -f '$STATE/default-applied' ]]"
rm "$MOCK_EASYEFFECTS_LOADED"
: > "$MOCK_EASYEFFECTS_COMMANDS"
assert_true "subsequent explicit personal preset is retained" "MOCK_PREVIOUS_PRESET=Personal easyeffects_apply_preset"
assert_file_not_contains "personal preset prevents reloading the managed preset" "$MOCK_EASYEFFECTS_COMMANDS" '--load-preset'
test_summary
