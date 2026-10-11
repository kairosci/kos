#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(dirname "$(dirname "$(readlink -f "$0")")")"
source "$PROJECT_ROOT/scripts/lib/i18n.sh"
source "$PROJECT_ROOT/scripts/lib/distribution.sh"
source "$PROJECT_ROOT/scripts/lib/release.sh"
i18n_init
[[ $EUID == 0 && ${KOS_APPLY_PIPELINE:-0} == 1 ]] || err release.root
if command -v mkarchiso >/dev/null; then
    kos_release_build "$PROJECT_ROOT" "$PROJECT_ROOT/dist"
else
    command -v podman >/dev/null || err release.tools podman
    install -d -m 755 "$PROJECT_ROOT/dist"
    image=$(cat "$PROJECT_ROOT/conf/kos/data/build-image")
    [[ "$image" =~ ^docker.io/library/archlinux@sha256:[a-f0-9]{64}$ ]] || err release.invalid
    epoch=$(git -C "$PROJECT_ROOT" log -1 --format=%ct)
    podman run --rm --privileged --volume "$PROJECT_ROOT:/var/tmp/kos-source:ro" \
        --volume "$PROJECT_ROOT/dist:/var/tmp/kos-artifacts" --env "SOURCE_DATE_EPOCH=$epoch" "$image" \
        bash -c 'set -euo pipefail; pacman -Syu --noconfirm --needed archiso qemu-system-x86 edk2-ovmf git zstd; source /var/tmp/kos-source/scripts/lib/i18n.sh; source /var/tmp/kos-source/scripts/lib/distribution.sh; source /var/tmp/kos-source/scripts/lib/release.sh; i18n_init; kos_release_build /var/tmp/kos-source /var/tmp/kos-artifacts; bash /var/tmp/kos-source/scripts/test-release-boot.sh /var/tmp/kos-artifacts'
fi
