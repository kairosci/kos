#!/usr/bin/env bash

Os::scripts::lib::namespace_cleanup_sh::run() {

namespace_archive_file() {
    local file="$1" namespace="$2" root="${OS_NAMESPACE_ROOT:-}" backup="${OS_NAMESPACE_BACKUP:-${OS_NAMESPACE_ROOT:-}/var/lib/os/previous-namespace}"
    [[ -e "$file" || -L "$file" ]] || return 0
    local destination="$backup/$namespace/${file#"$root"/}"
    [[ ! -e "$destination" && ! -L "$destination" ]] || return 1
    install -d -m 700 "${destination%/*}" || return 1
    mv "$file" "$destination"
}

namespace_cleanup() {
    local root="${OS_NAMESPACE_ROOT:-}" library namespace unit file units name description
    local -a namespaces=()
    for library in "$root"/usr/local/lib/*/i18n.sh; do
        [[ -f "$library" && ! -L "$library" ]] || continue
        namespace=${library%/i18n.sh}
        namespace=${namespace##*/}
        [[ "$namespace" =~ ^[a-z][a-z0-9_-]*$ && "$namespace" != os ]] || continue
        [[ $(stat -c %u "$library") == "${OS_NAMESPACE_OWNER_UID:-0}" ]] || continue
        grep -Fqx "declare -gA ${namespace^^}_I18N=()" "$library" || continue
        namespaces+=("$namespace")
    done
    for file in "$root"/etc/systemd/system/*-security-audit.service; do
        [[ -f "$file" && ! -L "$file" ]] || continue
        [[ $(stat -c %u "$file") == "${OS_NAMESPACE_OWNER_UID:-0}" ]] || continue
        namespace=${file##*/}
        namespace=${namespace%-security-audit.service}
        [[ "$namespace" =~ ^[a-z][a-z0-9_-]*$ && "$namespace" != os ]] || continue
        grep -qx 'ExecStart=/etc/cron.weekly/security-audit.sh' "$file" || continue
        if ! grep -Fqx "Description=${namespace^} security audit" "$file" && ! grep -Fqx "Description=${namespace^^} security audit" "$file"; then
            continue
        fi
        [[ " ${namespaces[*]} " != *" $namespace "* ]] || continue
        namespaces+=("$namespace")
    done
    for namespace in "${namespaces[@]}"; do
        log "namespace.start" "$namespace"
        for name in security-audit keyboard-backlight; do
            file="$root/etc/systemd/system/$namespace-$name.service"
            [[ -f "$file" && ! -L "$file" ]] || continue
            case "$name" in
                security-audit)
                    grep -qx 'ExecStart=/etc/cron.weekly/security-audit.sh' "$file" || continue
                    ;;
                keyboard-backlight)
                    grep -Fq "/usr/local/libexec/$namespace-keyboard-backlight" "$file" || continue
                    ;;
            esac
            unit="$namespace-$name.timer"
            if [[ -f "$root/etc/systemd/system/$unit" ]]; then
                systemctl disable --now "$unit" || return 1
                namespace_archive_file "$root/etc/systemd/system/$unit" "$namespace" || return 1
            fi
            if [[ "$name" == keyboard-backlight ]]; then
                systemctl disable --now "$namespace-$name.service" || return 1
                units=$(systemctl list-units --all --plain --no-legend "$namespace-$name@*.service") || return 1
                while read -r unit description; do
                    [[ -n "$unit" ]] || continue
                    [[ "$unit" == "$namespace-$name@"*.service ]] || return 1
                    systemctl stop "$unit" || return 1
                done <<< "$units"
                namespace_archive_file "$root/etc/systemd/system/$namespace-$name@.service" "$namespace" || return 1
            fi
            namespace_archive_file "$file" "$namespace" || return 1
        done
        for file in \
            "$root/etc/pacman.d/hooks/99-$namespace-desktop-cleanup.hook" \
            "$root/etc/pacman.d/hooks/99-$namespace-theme-previews.hook" \
            "$root/etc/udev/rules.d/99-$namespace-keyboard-backlight.rules" \
            "$root/usr/lib/systemd/system-sleep/$namespace-keyboard-backlight" \
            "$root/usr/lib/systemd/system-sleep/$namespace-battery-charge-limit"; do
            namespace_archive_file "$file" "$namespace" || return 1
        done
        for file in "$root"/home/*/.config/omarchy/hooks/{post-update,pre-refresh-pacman}.d/"99-$namespace-persist"; do
            namespace_archive_file "$file" "$namespace" || return 1
        done
    done
    systemctl daemon-reload
}

}

Os::scripts::lib::namespace_cleanup_sh::run "$@"
