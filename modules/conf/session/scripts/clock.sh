#!/usr/bin/env bash
set -euo pipefail

ClockWidget::new() {
    local -n target="$1"
    target["module"]="$2"
    target["stage"]="$3"
    target["policy"]="$4"
}

ClockWidget::stage() {
    local -n staged_widget="$1"
    local id directory
    id=$(jq -er '.clockWidget | select((.enabled | type == "boolean") and .anchor == "bottom-right" and (.format == "HH:mm" or .format == "hh:mm AP")) | .id | select(test("^[a-z][a-z0-9.]+$"))' "${staged_widget[policy]}") || err "session.validation_failed" clockWidget
    directory="${staged_widget[stage]}/plugins/$id"
    mkdir -p "$directory"
    cp "${staged_widget[module]}/qml/ClockWidget.qml" "$directory/"
    jq --arg id "$id" '.id = $id' "${staged_widget[module]}/data/clock-manifest.json" > "$directory/manifest.json"
}
