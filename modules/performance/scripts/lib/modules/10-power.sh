#!/bin/bash

Os::modules::performance::scripts::lib::modules::10_power_sh::run() {
set -euo pipefail

log "Configuring low-battery hibernate protection"
mkdir -p /etc/UPower/UPower.conf.d
cat > /etc/UPower/UPower.conf.d/99-os-low-battery.conf << 'UPOWER'
[UPower]
UsePercentageForPolicy=true
PercentageLow=20
PercentageCritical=10
PercentageAction=5
CriticalPowerAction=Hibernate
UPOWER
chmod 644 /etc/UPower/UPower.conf.d/99-os-low-battery.conf
systemctl restart upower.service 2>/dev/null || warn "upower restart skipped"

}

Os::modules::performance::scripts::lib::modules::10_power_sh::run "$@"
