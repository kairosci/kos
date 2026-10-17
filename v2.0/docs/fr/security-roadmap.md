# Programme sécurité et bureau

La référence du 13 octobre 2026 est historique. Le gel de l’état réel concernait cet audit, pas les changements actuels : les modifications autorisées passent par `make setup`. Aucun système n’est immunisé par définition ; chaque sprint exige périmètres de confiance, critères mesurables et récupération vérifiable.

L’observation comprenait 137 contrôles réussis avec six groupes privilégiés ignorés et 85 contrôles de compatibilité avec un avertissement Polkit. UFW, auditd, fail2ban, USBGuard, AppArmor, NetworkManager et Polkit étaient actifs ; SSH inactif. Secure Boot était désactivé, la racine Btrfs chiffrée. Hyprland ne signalait aucune erreur avec `misc:size_limits_tiled=false` ; vingt fichiers de bureau, l’inventaire des paquets et sept états de services étaient inchangés. Les tests des limites des hooks réussissaient 19 contrôles et l’idempotence 18 ; l’essai graphique interactif restait à faire.

L’empreinte du bureau était `cbe3b671ea633afe222d92bc07ae80ac1afb43f3db96c58c2fe362f463288831`, celle des paquets `33c1ded113f9ab107ae15222a0f7a0ec066d7994683596fa365867e8e42fc2fc`. Les manifestes sous `/tmp/os-baseline.8uINio` ne sont pas une récupération durable. Les PR 65 et 66 ont activé l’automatisation gratuite et Semgrep 1.180.0 sans installer de logiciel sur la machine.

Le parcours sécurité couvre référence, identités des sources et de l’installation, limites root/utilisateur/réseau/AUR/plugins, injections, environnement privilégié, secrets dans les journaux, liens symboliques, chaîne d’approvisionnement, ports et pare-feu, AppArmor, PAM, isolation des services, démarrage chiffré, dépendances vulnérables, dérive et tests adverses avec restauration. Chaque étape doit démontrer son résultat ; les anciens tests réussis ne remplacent pas les preuves absentes.

Le parcours bureau couvre géométrie réelle, maquette hors ligne, palette, barre Nautilus, dialogues de fichiers, menus contextuels, cases cochées, limites des fenêtres, échelle et écrans multiples, contraste et focus, usage de LazyVim et publication avec récupération. Une maquette HTML ne démontre pas un changement des menus natifs ; la souris dans l’éditeur ne crée pas une GUI de paramètres.

La livraison exige branche dédiée, revue, tests pertinents et comparaison à la référence après application autorisée. Conserver tiling automatique, verrouilleur unique, audio, réseau, authentification, Secret Service, swap et hibernation. Les scans GitHub portent sur les révisions publiées et ne certifient pas continuellement le système installé.
