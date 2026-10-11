#!/usr/bin/env bash

pam_policy_reconcile() {
    local target="$1" staged
    staged=$(mktemp "${target}.XXXXXX")
    if ! awk '
        /^[[:space:]]*#/ {print; next}
        /pam_pwquality\.so/ && $1 ~ /^-?password$/ {next}
        $1 ~ /^-?password$/ && !quality++ {
            print "password requisite pam_pwquality.so retry=3 enforce_for_root"
        }
        /pam_faillock\.so/ {
            faillock=1
            for (i=NF; i>1; i--)
                if ($i ~ /^(deny|unlock_time|conf)=/) {
                    for (j=i; j<NF; j++) $j=$(j+1)
                    NF--
                }
        }
        /pam_unix\.so/ && $1 ~ /^-?(auth|password)$/ {
            for (i=NF; i>1; i--)
                if ($i == "nullok") {
                    for (j=i; j<NF; j++) $j=$(j+1)
                    NF--
                }
            if ($1 ~ /^-?password$/) {
                unix_password=1
                if ($0 !~ /(^|[[:space:]])use_authtok([[:space:]]|$)/)
                    $0=$0 " use_authtok"
            }
        }
        {print}
        END {if (!faillock || !unix_password) exit 1}
    ' "$target" > "$staged"; then
        rm -f "$staged"
        return 1
    fi
    if cmp -s "$target" "$staged"; then
        rm -f "$staged"
        return 0
    fi
    if { [[ -e "${target}.omaconf-backup" ]] || cp -p "$target" "${target}.omaconf-backup"; } &&
        chmod --reference="$target" "$staged" &&
        chown --reference="$target" "$staged" &&
        mv -f "$staged" "$target"; then
        return 0
    fi
    rm -f "$staged"
    return 1
}
