---
name: structured-policy
description: Maintain module ownership, external policy data and complete localization during OS restructuring.
---

Each module owns its data, algorithms, interface and tests. Add submodules when they have distinct responsibilities and callers, not merely to increase directory depth. Put configurable values, package lists, menu entries, mappings and layout policy under the owning `data/` directory. Derive runtime paths, geometry and hardware values from validated system facts.

Do not compute policy choices such as charge limits or spacing from arbitrary hardware observations; store those decisions explicitly as policy. Reject missing required data instead of substituting invented values. Human messages use symbolic keys in all six catalogs with matching arguments. Machine identifiers and protocol syntax remain stable across locales.

Use actual implementations and observable assertions. Do not add empty modules, unfinished scaffolds, cosmetic class wrappers or hidden error suppression. Preserve independent archival backups and recovery entries until replacement behavior has been demonstrated.
