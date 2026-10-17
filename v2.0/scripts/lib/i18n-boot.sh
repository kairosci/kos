#!/usr/bin/env bash

_os_locale_stub() {
    t() { printf -- '%s' "$1"; }
    log() { printf '%s\n' "$1"; }
    warn() { printf '%s: %s\n' "Warning" "$1" >&2; }
    err() { printf '%s: %s\n' "Error" "$1" >&2; exit 1; }
}

_os_locale_resolve() {
    local candidate
    for candidate in \
        "$(dirname "${BASH_SOURCE[0]}")/i18n.sh" \
        "${OS_I18N_DIR:-}/i18n.sh" \
        "${SCRIPT_DIR:-.}/../i18n/i18n.sh" \
        "${SCRIPT_DIR:-.}/../../scripts/lib/i18n.sh"; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

if _os_i18n_path=$(_os_locale_resolve) && [[ -f "$_os_i18n_path" ]]; then
    # shellcheck disable=SC1090
    if source "$_os_i18n_path"; then
        _os_i18n_loaded=1
    else
        _os_locale_stub
        warn "Unable to load the internationalization library; using the English fallback."
        _os_i18n_loaded=0
    fi
    unset _os_i18n_path
    if [[ "$_os_i18n_loaded" == 1 ]] && declare -F t >/dev/null 2>&1; then
        if ! locale_init; then
            _os_locale_stub
            warn "Unable to initialize internationalization; using the English fallback."
        fi
    else
        _os_locale_stub
    fi
else
    unset _os_i18n_path
    _os_locale_stub
fi

unset -f _os_locale_resolve _os_locale_stub
