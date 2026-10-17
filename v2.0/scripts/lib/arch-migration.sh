#!/usr/bin/env bash

arch_migration_report() {
    local project="$1" policy="$1/modules/platform/arch/data/parity.json" packages repositories references ownership status official_names official_packages runtime_package runtime_pattern
    local -a official_repositories=()
    packages=$(pacman -Qq) || return 1
    repositories=$(pacman-conf --repo-list) || return 1
    official_names=$(jq -er '.officialRepositories[]' "$policy") || return 1
    mapfile -t official_repositories <<< "$official_names"
    official_packages=$(pacman -Slq "${official_repositories[@]}") || return 1
    runtime_package=$(jq -er '.runtimePackage' "$policy") || return 1
    runtime_pattern=$(jq -er '.runtimeReferencePattern' "$policy") || return 1
    if references=$(rg -l -e "$runtime_pattern" "$project/scripts" "$project/hooks" "$project/modules/conf" "$project/src" "$project/script"); then
        status=0
    else
        status=$?
        [[ "$status" == 1 ]] || return "$status"
    fi
    if pacman -Q "$runtime_package" >/dev/null; then
        ownership=$(pacman -Qlq "$runtime_package") || return 1
    else
        ownership=''
    fi
    jq -n --slurpfile policy "$policy" --rawfile packages <(printf '%s' "$packages") --rawfile repositories <(printf '%s' "$repositories") \
        --rawfile references <(printf '%s' "$references") --rawfile ownership <(printf '%s' "$ownership") --rawfile officialPackages <(printf '%s' "$official_packages") --arg runningKernel "$(uname -r)" '
        ($packages | split("\n")) as $installed
        | {schemaVersion:1,target:$policy[0].target,runningKernel:$runningKernel,
           externalPackages:[$policy[0].externalPackages[] | select(. as $p | $installed | index($p))],
           repositories:($repositories|split("\n")),
           packagesWithoutOfficialSource:($installed - ($officialPackages|split("\n"))),
           dependentSources:($references|split("\n")|map(select(length>0))),
           runtimeFileCount:($ownership|split("\n")|map(select(length>0 and (endswith("/")|not)))|length),
           capabilities:[$policy[0].requiredCapabilities[] | . + {missingPackages:[.packages[] | select(. as $p | $installed | index($p)|not)],parity:"unverified"}],
           readyToRemoveRuntime:false,readyToRemoveRepository:false,
           requiresTrialBoot:true}'
}

arch_migration_main() {
    local project
    [[ $# -le 1 ]] || return 2
    project="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    case "${1:---report}" in
        --report) arch_migration_report "$project" ;;
        --check) arch_migration_report "$project" | jq -e '.readyToRemoveRuntime and .readyToRemoveRepository and all(.capabilities[]; .parity == "verified")' ;;
        *) return 2 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -euo pipefail
    arch_migration_main "$@"
fi
