#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/test_lib.sh"

test_section "Script Syntax & Code Integrity"

for sh_file in "$PROJECT_DIR"/scripts/*.sh "$PROJECT_DIR"/scripts/lib/*.sh "$PROJECT_DIR"/scripts/lib/modules/*.sh "$PROJECT_DIR"/hooks/theme-set.d/* "$PROJECT_DIR"/hooks/pre-refresh-pacman.d/* "$PROJECT_DIR"/hooks/post-update.d/* "$PROJECT_DIR"/modules/conf/*/*.sh "$PROJECT_DIR"/modules/conf/*/scripts/*.sh "$PROJECT_DIR"/modules/theme-previews/scripts/*.sh "$PROJECT_DIR"/modules/theme-previews/scripts/lib/*.sh "$PROJECT_DIR"/tests/*.sh; do
    [[ -f "$sh_file" ]] || continue
    fname=$(basename "$sh_file")
    assert_true "syntax check: $fname" "bash -n '$sh_file'"
done

assert_true "syntax check: herdr-keybindings-menu" "bash -n '$PROJECT_DIR/data/component/application/herdr/menu'"
assert_true "Lua syntax check: application keybindings" "luac -p '$PROJECT_DIR/src/component/application/keybindings.lua'"
assert_file_exists "Bash SAST workflow exists" "$PROJECT_DIR/../.github/workflows/sast.yml"
assert_file_exists "SAST dependency manifest exists" "$PROJECT_DIR/requirements-sast.txt"
assert_file_exists "Local Bash SAST rules exist" "$PROJECT_DIR/.semgrep.yml"
assert_file_contains "SAST dependency is version pinned" "$PROJECT_DIR/requirements-sast.txt" '^semgrep==[0-9.]+$'
assert_file_contains "Bash SAST uploads SARIF" "$PROJECT_DIR/../.github/workflows/sast.yml" 'upload-sarif@'
assert_file_contains "Bash SAST uses local rules" "$PROJECT_DIR/../.github/workflows/sast.yml" 'config v2.0/.semgrep.yml'
assert_file_contains "Bash SAST fails on security findings" "$PROJECT_DIR/../.github/workflows/sast.yml" '^[[:space:]]+--error'
assert_file_contains "Dependabot tracks SAST dependencies" "$PROJECT_DIR/../.github/dependabot.yml" 'package-ecosystem: pip'
assert_file_exists "security policy exists" "$PROJECT_DIR/SECURITY.md"
assert_file_contains "Arch CI installs the YAML test dependency" "$PROJECT_DIR/../.github/workflows/ci.yml" 'base-devel git sudo jq python python-yaml'
assert_true "CI checkout actions use immutable refs" "! grep -q 'uses: actions/checkout@v' '$PROJECT_DIR/../.github/workflows/ci.yml'"
assert_file_exists "Lua test entry point exists" "$PROJECT_DIR/tests/main.lua"
assert_file_exists "Lua suite orchestration exists" "$PROJECT_DIR/src/component/testing/runner.lua"
assert_file_contains "suite policy includes native Lua tests" "$PROJECT_DIR/data/component/testing/policy.json" 'tests/lua/run.lua'
assert_file_contains "suite runner reports executed assertions" "$PROJECT_DIR/src/component/testing/runner.lua" 'Tests Executed: %d'
assert_file_contains_literal "root modules live under lib" "$PROJECT_DIR/scripts/setup.sh" 'MODULES_DIR="$SCRIPT_DIR/lib/modules"'

markdown_lists=0
markdown_scan_failed=0
while IFS= read -r -d '' markdown_file; do
    if grep -qE '^[[:space:]]*([-*+][[:space:]]+|[0-9]+[.)][[:space:]]+)' "$PROJECT_DIR/$markdown_file"; then
        markdown_lists=1
    else
        grep_status=$?
        [[ "$grep_status" -eq 1 ]] || markdown_scan_failed=1
    fi
done < <(git -C "$PROJECT_DIR" ls-files -z -- '*.md' '*.mdx')
assert_true "tracked Markdown documentation uses prose instead of lists" "[[ '$markdown_lists' -eq 0 && '$markdown_scan_failed' -eq 0 ]]"

assert_file_executable "scripts/setup.sh is executable" "$PROJECT_DIR/scripts/setup.sh"
assert_file_executable "scripts/verify.sh is executable" "$PROJECT_DIR/scripts/verify.sh"
assert_file_executable "hooks/theme-set.d/folder-color is executable" "$PROJECT_DIR/hooks/theme-set.d/folder-color"
assert_file_executable "hooks/pre-refresh-pacman.d/99-os-persist is executable" "$PROJECT_DIR/hooks/pre-refresh-pacman.d/99-os-persist"
assert_file_executable "hooks/post-update.d/99-os-persist is executable" "$PROJECT_DIR/hooks/post-update.d/99-os-persist"
assert_file_executable "modules/conf/zed/install.sh is executable" "$PROJECT_DIR/modules/conf/zed/install.sh"
assert_true "Herdr Bash installer is retired" "[[ ! -e '$PROJECT_DIR/modules/conf/herdr/install.sh' ]]"
assert_file_exists "Herdr menu payload is under application data" "$PROJECT_DIR/data/component/application/herdr/menu"

for mod in "$PROJECT_DIR"/scripts/lib/modules/*.sh; do
    [[ -f "$mod" ]] || continue
    mname=$(basename "$mod")
    assert_file_executable "module $mname is executable" "$mod"
    assert_file_contains "module $mname uses strict mode" "$mod" "set -euo pipefail"
done

assert_file_executable "scripts/lib/i18n.sh is executable" "$PROJECT_DIR/scripts/lib/i18n.sh"
assert_true "i18n.sh does not alter caller shell options" "bash -c 'set +e +u; source \"$PROJECT_DIR/scripts/lib/i18n.sh\"; [[ \$- != *e* && \$- != *u* ]]'"
assert_true "locale-map.sh does not alter caller shell options" "bash -c 'set +e +u; source \"$PROJECT_DIR/scripts/lib/locale-map.sh\"; [[ \$- != *e* && \$- != *u* ]]'"
assert_file_contains "setup.sh uses strict mode" "$PROJECT_DIR/scripts/setup.sh" "set -euo pipefail"
assert_file_contains "verify.sh uses strict mode" "$PROJECT_DIR/scripts/verify.sh" "set -uo pipefail"
assert_file_contains "folder-color uses strict mode" "$PROJECT_DIR/hooks/theme-set.d/folder-color" "set -euo pipefail"
assert_file_contains "pre-refresh persist hook uses strict mode" "$PROJECT_DIR/hooks/pre-refresh-pacman.d/99-os-persist" "set -euo pipefail"
assert_file_contains "post-update persist hook uses strict mode" "$PROJECT_DIR/hooks/post-update.d/99-os-persist" "set -euo pipefail"

test_summary
