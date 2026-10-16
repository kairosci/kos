#!/usr/bin/env bash

Os::modules::conf::session::scripts::environment_sh::run() {
# shellcheck shell=bash
_os_session_policy="${XDG_DATA_HOME:-$HOME/.local/share}/os/session/data/policy.json"
_os_session_qs=$(jq -er '.runtime + "/shell"' "$_os_session_policy") || return 1
export QS_CONFIG_PATH="$_os_session_qs"
unset _os_session_policy _os_session_qs

}

Os::modules::conf::session::scripts::environment_sh::run "$@"
