#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
source "$PROJECT_DIR/scripts/lib/i18n.sh"
source "$PROJECT_DIR/scripts/lib/userconf.sh"
i18n_init

config="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
[[ -f "$config" ]] || exit 0
[[ ! -L "$config" ]] || err "defaults.app_failed" "agents"
staged=$(mktemp)
trap 'rm -f "$staged"' EXIT
jq '
    if .bar.layout | type == "object" then .bar.layout |= with_entries(
        .value |= map(
            if . == "omarchy.agents" then {id: ., providers: {claude: {enabled: false}}}
            elif type == "object" and .id == "omarchy.agents" then
                .providers.claude.enabled = false
            else . end
        )
    ) else . end
' "$config" > "$staged" || err "defaults.app_failed" "agents"
install_user_content "$config" 600 < "$staged"
log "gui.install_done" "agents"
