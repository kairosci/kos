#!/usr/bin/env bash

snapshot_baseline_inventory() {
    local config="$1" rows number default active extra
    rows=$(LC_ALL=C snapper --csvout --no-headers -c "$config" list --columns number,default,active) || return 1
    SNAPSHOT_IDS=()
    SNAPSHOT_PROTECTED=()
    while IFS=, read -r number default active extra; do
        number=${number//\"/}
        default=${default//\"/}
        active=${active//\"/}
        [[ "$number" =~ ^[0-9]+$ && -z "$extra" ]] || return 1
        case "$default:$active" in
            no:no|false:false|0:0) ;;
            yes:no|no:yes|yes:yes|true:false|false:true|true:true|1:0|0:1|1:1)
                SNAPSHOT_PROTECTED+=("$number")
                ;;
            *) return 1 ;;
        esac
        SNAPSHOT_IDS+=("$number")
    done <<< "$rows"
    ((${#SNAPSHOT_IDS[@]}))
}

snapshot_baseline_reset() {
    local rows config baseline marker number protected state="${OS_SNAPSHOT_BASELINE_STATE:-/var/lib/os/snapshot-baseline}"
    local -a configs=() remove=()
    if ! command -v snapper >/dev/null || ! command -v limine-snapper-sync >/dev/null; then
        return 1
    fi
    [[ ! -e /var/lib/pacman/db.lck ]] || return 1
    rows=$(LC_ALL=C snapper --csvout --no-headers list-configs --columns config) || return 1
    while IFS= read -r config; do
        config=${config//\"/}
        [[ "$config" =~ ^[a-zA-Z0-9_-]+$ ]] || return 1
        configs+=("$config")
    done <<< "$rows"
    ((${#configs[@]})) || return 1
    install -d -m 700 "$state" || return 1
    for config in "${configs[@]}"; do
        snapshot_baseline_inventory "$config" || return 1
        marker="$state/$config"
        [[ ! -L "$marker" ]] || return 1
        baseline=""
        if [[ -f "$marker" ]]; then
            baseline=$(cat "$marker") || return 1
            [[ "$baseline" =~ ^[1-9][0-9]*$ ]] || return 1
            if [[ " ${SNAPSHOT_IDS[*]} " != *" $baseline "* ]]; then
                baseline=""
            fi
        fi
        if [[ -z "$baseline" ]]; then
            baseline=$(LC_ALL=C snapper -c "$config" create --type single --read-only --print-number --description "$(t snapshots.description)" --userdata important=yes) || return 1
            [[ "$baseline" =~ ^[1-9][0-9]*$ ]] || return 1
            printf '%s\n' "$baseline" > "$marker" || return 1
            log "snapshots.created" "$config" "$baseline"
        fi
        snapshot_baseline_inventory "$config" || return 1
        [[ " ${SNAPSHOT_IDS[*]} " == *" $baseline "* ]] || return 1
        remove=()
        for number in "${SNAPSHOT_IDS[@]}"; do
            [[ "$number" != 0 && "$number" -lt "$baseline" ]] || continue
            protected=0
            if [[ " ${SNAPSHOT_PROTECTED[*]} " == *" $number "* ]]; then
                protected=1
            fi
            if ((protected)); then
                warn "snapshots.protected" "$config" "$number"
            else
                remove+=("$number")
            fi
        done
        if ((${#remove[@]})); then
            snapper -c "$config" delete --sync "${remove[@]}" || return 1
        fi
        snapshot_baseline_inventory "$config" || return 1
        for number in "${remove[@]}"; do
            [[ " ${SNAPSHOT_IDS[*]} " != *" $number "* ]] || return 1
        done
        log "snapshots.done" "$config" "$baseline" "${#remove[@]}"
    done
    limine-snapper-sync || return 1
}
