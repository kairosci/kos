# Set default XCompose that is triggered with CapsLock
tee ~/.XCompose >/dev/null <<EOF
# Run kos-restart-xcompose to apply changes

# Include fast emoji access
include "/usr/share/kos/default/xcompose"

# Identification
<Multi_key> <space> <n> : "$KOS_USER_NAME"
<Multi_key> <space> <e> : "$KOS_USER_EMAIL"
EOF
