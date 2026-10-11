#!/usr/bin/env bash

kos_manifest_create() {
    local output="$1" release="$2" file metadata name version
    local -a entries=()
    for file in "$output"/kos-*.pkg.tar.zst; do
        [[ -f "$file" ]] || return 1
        metadata=$(pacman -Qp "$file") || return 1
        read -r name version <<< "$metadata"
        [[ "$name" == kos ]] || return 1
        entries+=("$(jq -cn --arg name "$name" --arg version "$version" --arg file "${file##*/}" \
            --arg sha256 "$(sha256sum "$file" | cut -d' ' -f1)" \
            '{name: $name, version: $version, file: $file, sha256: $sha256}')")
    done
    [[ ${#entries[@]} == 1 ]] || return 1
    printf '%s\n' "${entries[@]}" | jq -s --arg release "$release" \
        '{release: $release, packages: .}' > "$output/PACKAGES.json" || return 1
    kos_manifest_valid "$output/PACKAGES.json" "$release"
}

kos_manifest_valid() {
    jq -e --arg release "$2" '
        .release == $release and
        (.packages | length == 1) and
        ([.packages[].name] == ["kos"]) and
        all(.packages[];
            (.version | test("^[0-9][A-Za-z0-9.+:_-]*$")) and
            (.file == (.name + "-" + .version + "-x86_64.pkg.tar.zst")) and
            (.sha256 | test("^[a-f0-9]{64}$"))) and
        any(.packages[]; .name == "kos" and .version == ($release + "-1"))
    ' "$1" >/dev/null
}
