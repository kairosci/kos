# Documentation

Repository documentation is maintained in this directory. Root paths required by GitHub or repository tools resolve to their canonical documents here, and module runbooks are exposed through the paths expected by their projects.

## Repository

The [project overview](root/README.md) explains installation and operation. The [agent instructions](root/AGENTS.md) define repository ownership and change policy. The [security policy](root/SECURITY.md) describes vulnerability reporting, while the [audit](root/AUDIT.md) records verified security and system findings. The [security and desktop roadmap](security-roadmap.md) tracks planned work. GitHub pull requests use the [empty body template](github/PULL_REQUEST_TEMPLATE.md).

## Modules

Application setup is documented in [application configuration](modules/conf/README.md), and desktop captures are described in [theme previews](modules/theme-previews/README.md). The [clean](modules/clean/README.md), [obscure](modules/obscure/README.md), and [performance](modules/performance/README.md) modules have dedicated documentation. The [OSMP plugin](modules/plugins/osmp/README.md) explains its local integration. [ISO release and customization](modules/iso/README.md) covers the generated installation media.

## Agent runbooks

Operational runbooks are stored in [skills](skills/) and exposed through the `.skills/` paths used by repository tooling.
