#!/usr/bin/env bash

Os::scripts::lib::modules::81_resolver_failover_sh::run() {
set -euo pipefail

log "services.resolver_failover"
install -d -m 0755 /etc/NetworkManager/conf.d
install -d -m 0755 /usr/local/libexec
install -m 0755 "$PROJECT_DIR/scripts/lib/resolver-failover.sh" /usr/local/libexec/os-resolver-failover || err "services.resolver_failover_failed"
install -D -m 0644 "$PROJECT_DIR/conf/network/data/os-resolver-failover.service" /etc/systemd/system/os-resolver-failover.service || err "services.resolver_failover_failed"
systemctl daemon-reload || err "services.resolver_failover_failed"
systemctl enable --now os-resolver-failover.service || err "services.resolver_failover_failed"
systemctl try-restart os-resolver-failover.service || err "services.resolver_failover_failed"

}

Os::scripts::lib::modules::81_resolver_failover_sh::run "$@"
