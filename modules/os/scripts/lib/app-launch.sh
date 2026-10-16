#!/usr/bin/env bash
set -euo pipefail

os_app_require() {
    command -v "$1" >/dev/null || { os_err os.app_dependency_missing "$1"; return 1; }
}

os_app_desktop_path() {
    local id="$1" directory relative file files
    local -a directories=()
    IFS=: read -r -a directories <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    directories=("${XDG_DATA_HOME:-$HOME/.local/share}" "${directories[@]}")
    for directory in "${directories[@]}"; do
        [[ "$directory" == /* && -d "$directory/applications" ]] || continue
        if [[ -f "$directory/applications/$id" ]]; then
            printf '%s\n' "$directory/applications/$id"
            return 0
        fi
        files=$(find "$directory/applications" -mindepth 2 -name '*.desktop' -type f -print) || return 1
        while IFS= read -r file; do
            relative=${file#"$directory/applications/"}
            if [[ "${relative//\//-}" == "$id" ]]; then
                printf '%s\n' "$file"
                return 0
            fi
        done <<< "$files"
    done
    return 1
}

os_app_desktop_valid() {
    awk '
        { sub(/\r$/, "") }
        /^\[/ { main = ($0 == "[Desktop Entry]") }
        main && /^Type=/ { application = ($0 == "Type=Application") }
        main && /^Hidden=/ { hidden = ($0 == "Hidden=true") }
        END { exit !(application && !hidden) }
    ' "$1"
}

os_app_private_valid() {
    awk -v action="$2" '
        { sub(/\r$/, "") }
        /^\[/ { main = ($0 == "[Desktop Entry]"); private = ($0 == "[Desktop Action " action "]") }
        main && /^Actions=/ { count = split(substr($0,9), actions, ";"); for (i=1; i<=count; i++) if (actions[i] == action) declared=1 }
        private && /^Exec=.+/ { executable=1 }
        END { exit !(declared && executable) }
    ' "$1"
}

os_app_main() {
    local resolve=0 role policy="$1" selector desktop file private=0 action argument
    shift
    local -a arguments=()
    if [[ "${1:-}" == --resolve ]]; then resolve=1; shift; fi
    if [[ $# == 0 || "${1:-}" == --help ]]; then
        printf '%s\n' "$(os_msg os.app_usage)"
        return 0
    fi
    role="$1"
    shift
    os_app_require jq || return 1
    selector=$(jq -er --arg role "$role" '.[$role].selector | select(.=="browser" or .=="mime" or .=="desktop")' "$policy") || {
        os_err os.app_invalid "$role"
        return 1
    }
    case "$selector" in
        browser)
            os_app_require xdg-settings || return 1
            desktop=$(env -u BROWSER xdg-settings get default-web-browser) || { os_err os.app_default_missing "$role"; return 1; }
            if [[ -z "$desktop" ]]; then
                os_app_require xdg-mime || return 1
                argument=$(jq -er --arg role "$role" '.[$role].fallbackMime' "$policy") || return 1
                desktop=$(xdg-mime query default "$argument") || { os_err os.app_default_missing "$role"; return 1; }
            fi
            ;;
        mime)
            os_app_require xdg-mime || return 1
            argument=$(jq -er --arg role "$role" '.[$role].mime' "$policy") || return 1
            desktop=$(xdg-mime query default "$argument") || { os_err os.app_default_missing "$role"; return 1; }
            ;;
        desktop) desktop=$(jq -er --arg role "$role" '.[$role].desktop' "$policy") || return 1 ;;
    esac
    [[ "$desktop" =~ ^[[:alnum:]][[:alnum:]_.-]*\.desktop$ ]] || { os_err os.app_default_missing "$role"; return 1; }
    file=$(os_app_desktop_path "$desktop") || { os_err os.app_default_missing "$role"; return 1; }
    os_app_desktop_valid "$file" || { os_err os.app_default_missing "$role"; return 1; }
    for argument in "$@"; do
        if [[ "$role" == browser && "$argument" == --private ]]; then
            private=1
        elif [[ "$argument" == -* ]]; then
            os_err os.app_invalid "$argument"
            return 1
        else
            arguments+=("$argument")
        fi
    done
    if [[ "$private" == 1 ]]; then
        action=$(jq -er --arg role "$role" '.[$role].privateAction | select(test("^[a-zA-Z][a-zA-Z0-9_-]*$"))' "$policy") || return 1
        os_app_private_valid "$file" "$action" || { os_err os.app_private_missing "$desktop"; return 1; }
        desktop+=":$action"
    fi
    os_app_require uwsm-app || return 1
    os_session_environment || return 1
    if [[ "$resolve" == 1 ]]; then
        jq -n --arg role "$role" --arg desktop "$desktop" --arg file "$file" --argjson private "$private" \
            --args '{role:$role,desktop:$desktop,desktopFile:$file,private:($private==1),argv:["uwsm-app","--",$desktop]+$ARGS.positional}' -- "${arguments[@]}"
        return 0
    fi
    exec uwsm-app -- "$desktop" "${arguments[@]}"
}
