# Performance du sous-projet historique

Ce sous-projet conserve l’ancienne automatisation Bash. La configuration actuelle du bureau est décrite dans le guide de performance et appliquée par `make setup SCOPE=performance`. Les politiques actuelles prévalent sur les anciens scripts autonomes.

Les réglages historiques comprennent la limite de charge à 75 % avec persistance, UPower aux seuils 20/10/5 et hibernation critique, TRIM et ajustements du noyau. L’ancienne désactivation du watchdog NMI ne décrit pas la politique actuelle et ne doit pas être réintroduite implicitement.

La vérification distingue les interfaces matérielles prises en charge, les valeurs réellement relues et les réglages simplement déclarés. Swap, hibernation, audio et session doivent rester fonctionnels. Aucune optimisation ne garantit l’absence absolue d’OOM, de latence ou de blocage pour toute charge.
