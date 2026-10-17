# DNS Resolver Failover

The `81-resolver-failover.sh` setup module installs a system service that checks DNS resolution once per minute while NetworkManager reports a connected link with full or limited internet connectivity. It probes `archlinux.org`, `github.com`, and `herdr.dev` through `systemd-resolved`. Three consecutive failed checks switch the Omarchy DNS provider between Cloudflare and Google; DHCP and custom providers fall back to Cloudflare. The service verifies the new resolver, keeps the selected provider after recovery, and waits 15 minutes before another provider change.

The service uses `omarchy dns` to apply changes so NetworkManager and `systemd-resolved` stay in sync. Run `omarchy dns Cloudflare`, `omarchy dns Google`, `omarchy dns DHCP`, or `omarchy dns Custom` to choose a provider manually. A later DNS outage can trigger automatic failover again.
