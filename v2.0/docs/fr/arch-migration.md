# Migration du runtime vers Arch

[Italiano](../it/arch-migration.md) · [English](../en/arch-migration.md) · [Français](arch-migration.md)

Le système s’identifie déjà comme Arch Linux. L’objectif supplémentaire est de retirer le runtime Omarchy en conservant des fonctions équivalentes. `os app` résout navigateur, éditeur graphique, gestionnaire de fichiers et Paramètres sans charger ou lancer Omarchy ; cela ne démontre pas la parité du bureau entier.

Le navigateur suit la préférence XDG puis l’association HTTPS si elle est vide. Éditeur et gestionnaire de fichiers suivent les associations MIME. Paramètres ouvre `os.settings.desktop`. Les entrées utilisateur précèdent celles du système, y compris les substitutions masquées. Identifiants, arguments et action privée sont validés ; Exec n’est pas interprété. `os app browser --private` exige l’action déclarée `new-private-window` et ne lance aucune fenêtre normale si elle manque. Espaces et métacaractères restent littéraux ; les options inconnues sont refusées. Utiliser des chemins absolus pour les noms commençant par un tiret.

`os app --resolve browser https://example.org` produit du JSON sans lancer d’application. `make setup SCOPE=cli` installe dispatcher, politique et catalogues sans mettre à jour les paquets, modifier les associations ou redémarrer des services. Applications, outils XDG et UWSM doivent être disponibles. Voir le [manuel UWSM](https://github.com/Vladimir-csp/uwsm/blob/master/man/uwsm-app.1.scd).

L’inventaire `data/component/platform/parity.json` distingue fonctions vérifiées et paquets simplement installés. Menu, session, notifications, fond, unique verrouilleur, répertoire de travail du terminal, options historiques, mise à jour et récupération exigent des remplaçants indépendants et testés.

Avant retrait, il faut une session d’essai isolée et des validations du démarrage à froid, de la suspension, de la reprise et de la récupération. Tous les paquets propres aux dépôts actuels exigent une alternative. Runtime, dépôts, clés, noyau et entrées de secours restent actifs tant que ces conditions ne sont pas remplies. La [transition EFI](boot-transition.md) distingue préparation des images et essais matériels.

## Mise à niveau de 1.9 vers 2.0

Avant la mise à niveau, sauvegarder les données personnelles et noter l’instantané actif, le noyau, l’entrée du firmware et l’état des services essentiels. Exécuter `make test`, `make verify` et `bash v2.0/scripts/test-os-compat.sh` ; conserver leurs résultats avec ceux de `v2.0/script/os-lua migration-report` et `v2.0/script/os-lua arch-report`. Ces contrôles ne remplacent pas les essais matériels.

Appliquer les changements uniquement par le pipeline privilégié du dépôt. Conserver Limine, le noyau fonctionnel, les dépôts et clés Omarchy, les instantanés et les entrées EFI de secours. Ne pas lancer le provisionnement complet depuis un instantané ou une racine temporaire. Si le système démarre depuis un instantané Snapper, utiliser uniquement `make setup SCOPE=recovery` : cette commande sauvegarde les configurations dans le home persistant et restaure l’instantané démarré.

Consigner séparément les résultats du démarrage à froid, du déverrouillage chiffré, de la session graphique, du réseau, de l’audio, de la suspension, de la reprise et de la récupération. Pour GRUB, l’installation et la sélection temporaire ne prouvent pas un démarrage réussi : conserver Limine jusqu’à la fin de tous les essais. Ne pas réinitialiser l’historique des instantanés avant d’avoir démarré la racine persistante et vérifié le bureau restauré.

La version 2.0 est prête uniquement si le rapport Lua ne trouve aucun algorithme Bash ou Ruby actif, si l’évaluation Arch confirme les capacités indépendantes d’Omarchy et si chaque essai matériel requis a un résultat consigné. Sinon, conserver la version 1.9 et ses voies de récupération.
