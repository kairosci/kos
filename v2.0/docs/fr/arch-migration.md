# Migration du runtime vers Arch

[Italiano](../it/arch-migration.md) · [English](../en/arch-migration.md) · [Français](arch-migration.md)

Le système s’identifie déjà comme Arch Linux. L’objectif supplémentaire est de retirer le runtime Omarchy en conservant des fonctions équivalentes. `os app` résout navigateur, éditeur graphique, gestionnaire de fichiers et Paramètres sans charger ou lancer Omarchy ; cela ne démontre pas la parité du bureau entier.

Le navigateur suit la préférence XDG puis l’association HTTPS si elle est vide. Éditeur et gestionnaire de fichiers suivent les associations MIME. Paramètres ouvre `os.settings.desktop`. Les entrées utilisateur précèdent celles du système, y compris les substitutions masquées. Identifiants, arguments et action privée sont validés ; Exec n’est pas interprété. `os app browser --private` exige l’action déclarée `new-private-window` et ne lance aucune fenêtre normale si elle manque. Espaces et métacaractères restent littéraux ; les options inconnues sont refusées. Utiliser des chemins absolus pour les noms commençant par un tiret.

`os app --resolve browser https://example.org` produit du JSON sans lancer d’application. `make setup SCOPE=cli` installe dispatcher, politique et catalogues sans mettre à jour les paquets, modifier les associations ou redémarrer des services. Applications, outils XDG et UWSM doivent être disponibles. Voir le [manuel UWSM](https://github.com/Vladimir-csp/uwsm/blob/master/man/uwsm-app.1.scd).

L’inventaire `data/component/platform/parity.json` distingue fonctions vérifiées et paquets simplement installés. Menu, session, notifications, fond, unique verrouilleur, répertoire de travail du terminal, options historiques, mise à jour et récupération exigent des remplaçants indépendants et testés.

Avant retrait, il faut une session d’essai isolée et des validations du démarrage à froid, de la suspension, de la reprise et de la récupération. Tous les paquets propres aux dépôts actuels exigent une alternative. Runtime, dépôts, clés, noyau et entrées de secours restent actifs tant que ces conditions ne sont pas remplies. La [transition EFI](boot-transition.md) distingue préparation des images et essais matériels.
