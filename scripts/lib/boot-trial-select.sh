#!/usr/bin/env bash
set -euo pipefail

boot_trial_select() {
    local policy="$1" label id firmware entry before after selected
    label=$(jq -er '.candidateLabel' "$policy") || return 1
    id=$(jq -er '.candidateId | select(test("^[A-Za-z][A-Za-z-]*$"))' "$policy") || return 1
    firmware=$(efibootmgr -v) || return 1
    before=$(sed -n 's/^BootOrder: //p' <<< "$firmware")
    [[ "$before" =~ ^[[:xdigit:]]{4}(,[[:xdigit:]]{4})*$ ]] || return 1
    entry=$(awk -F '\t' -v label="$label" -v loader="\\\\EFI\\\\$id\\\\grubx64.efi" '
        /^Boot[[:xdigit:]]{4}/ {
            description=$1
            sub(/^Boot[[:xdigit:]]{4}[*]?[[:space:]]+/, "", description)
            if (description == label && index($0, loader)) print substr($0, 5, 4)
        }
    ' <<< "$firmware") || return 1
    [[ "$entry" =~ ^[[:xdigit:]]{4}$ ]] || return 1
    efibootmgr --bootnext "$entry" || return 1
    firmware=$(efibootmgr -v) || return 1
    after=$(sed -n 's/^BootOrder: //p' <<< "$firmware")
    selected=$(sed -n 's/^BootNext: //p' <<< "$firmware")
    [[ "$after" == "$before" && "$selected" == "$entry" ]] || return 1
    log "bootloader.trial_selected" "$entry"
}
