# OS

[Italiano](../../it/root/README.md) · [English](../../en/root/README.md) · [Français](README.md)

OS configure un bureau Arch Linux existant par un provisioning appartenant au dépôt. L’installation active exige encore Omarchy. L’indépendance du runtime est un objectif, pas un remplacement achevé : paquets installés et anciens tests verts ne démontrent pas la parité des nouvelles implémentations.

`v2.0/` est l’unique arborescence active des versions présentes et futures ; `v1.0/` conserve l’archive originale immuable. Les algorithmes appartiennent à `src/core/` et `src/component/`, les politiques et ressources à `data/`, les lanceurs indispensables à `script/`, les tests à `tests/` et la documentation aux répertoires linguistiques. L’inventaire continue de signaler les algorithmes Bash restants. QML, CSS, entrées desktop et unités systemd conservent leurs formats natifs.

## Installation et utilisation

Travailler depuis la racine du dépôt ou `v2.0/`. `make setup` demande une authentification Polkit locale et exécute la pipeline privilégiée. Préparer d’abord les modifications dans le dépôt ; ne pas copier directement des corrections dans le système ou la session. Le setup complet réconcilie paquets, applications, thèmes, authentification, pare-feu, sécurité, matériel et bureau. Les opérations destructives ou de récupération restent explicitement sélectionnées.

| Commande | Fonction |
| --- | --- |
| `make help` | Référence localisée |
| `make test` | Suites automatiques du dépôt |
| `make verify` | Contrôles en lecture du système appliqué |
| `make setup SCOPE=cli` | Dispatcher Lua et rôles applicatifs |
| `make setup SCOPE=lua-applications` | Configurations applicatives migrées |
| `make setup SCOPE=settings` | Paramètres unifiés et intégration HyprMod |
| `make setup SCOPE=session` | Validation et publication de la session |
| `make setup SCOPE=wallpaper` | Fond unique avec logo et palette |
| `make setup SCOPE=performance` | Réactivité et budgets de l’éditeur |
| `make setup SCOPE=keyboard` | Rétroéclairage du clavier |
| `make setup SCOPE=boot-assessment` | Inventaire et vérification du démarrage |

`RUN_MIGRATIONS=1` exécute les vraies migrations natives avant le nettoyage, sans fabriquer de marqueurs. `RESTORE_OMARCHY=1` sauvegarde les configurations avant restauration. `RESET_SNAPSHOTS=1` crée et vérifie une référence avant de retirer les anciens snapshots ; zéro, actif et défaut sont conservés. Le provisioning normal refuse les racines temporaires de snapshots. La récupération conserve les sauvegardes sur le répertoire personnel persistant.

## Bureau et applications

Super et virgule ouvre Paramètres avec bureau, réseau, Bluetooth, audio et alimentation. Les changements du compositeur sont validés, sérialisés et enregistrés automatiquement. NetworkManager, BlueZ et PipeWire conservent services et profils. IP avancé, VPN, authentification d’entreprise et agent PIN Bluetooth intégré restent incomplets ; voir [Paramètres](../settings.md).

Brave Origin est le navigateur, Zed l’éditeur graphique, LazyVim empaqueté l’éditeur terminal et Nautilus le gestionnaire avec GVFS et File Roller. OnlyOffice traite les documents bureautiques, Papers les PDF, Loupe les images, Celluloid les médias, Baobab l’espace disque et Resources les ressources système. GTK fournit les dialogues de fichiers ; Hyprland les captures et le partage d’écran. Les bibliothèques GTK requises n’impliquent pas l’installation du bureau GNOME. GNOME Keyring fournit Secret Service avec Seahorse ; données et configurations personnelles retirées sont préservées.

`os app` résout les entrées desktop et transmet des arguments littéraux à UWSM. `os app --resolve settings` produit du JSON sans lancer de fenêtre. La navigation privée exige l’action déclarée du navigateur. Dispatcher et installation sont des composants Lua ; le lanceur localise uniquement le runtime. Les autres groupes conservent le contrat natif. Voir le [guide de commande](../modules/os/README.md).

Chaque thème expose un seul fond avec logo et palette. Les variantes précédentes et fonds personnels supplémentaires sont archivés hors du sélecteur, en conservant originaux empaquetés et données personnelles. GTK, icônes et Zed suivent la palette active. Les aperçus capturent le moniteur réel entier avec des fenêtres isolées, puis rétablissent thème, espace de travail, fond et notifications à chaque sortie. L’application passe par setup, avec `REBUILD_PREVIEWS=1` lorsque demandé.

## Sécurité et ressources

Setup possède sysctl, PAM, UFW, isolation SSH, AppArmor, auditd, fail2ban, USBGuard et analyses programmées. D-Bus, Polkit, NetworkManager, gestionnaire de connexion, audio et unique verrouilleur doivent rester fonctionnels. L’audit enregistre les détections à examiner ; il ne supprime pas automatiquement de fichiers et ne certifie pas l’absence de malware ou de vulnérabilité. Voir la [politique de sécurité](SECURITY.md).

La réactivité surveille les slices des applications et du fond, conserve swap et hibernation et protège la session sans redémarrer bureau ou audio. Les budgets adaptatifs réduisent la concurrence quand les ressources manquent. Une intervention OOM peut arrêter un scope applicatif et perdre du travail non enregistré ; aucune politique ne garantit l’absence d’épuisement ou de blocage sous toute charge. Voir [performances](../performance.md).

Charge de batterie et luminosité du clavier sont détectées selon les capacités puis vérifiées par relecture matérielle. Un firmware incompatible est signalé sans inventer une limite appliquée. Suspension et reprise préservent verrouilleur et ordre natif d’extinction du clavier.

## Démarrage et indépendance Arch

L’inventaire vérifie l’intégrité EFI et préserve chiffrement, racines des snapshots, sécurité et resume. GRUB reste un candidat séparé ; le premier essai matériel est revenu à Limine. Le candidat autonome recherche l’ESP par UUID en conservant ordre permanent et secours. Plymouth textuel est vérifié dans les images courantes. Démarrage, déchiffrement, suspension et récupération nécessitent des essais matériels ; aucun redémarrage automatique n’est effectué. Voir [transition de démarrage](../boot-transition.md) et [migration Arch](../arch-migration.md).

## Développement et publications

Les changements partent de branches dédiées et entrent dans `main` par PR signées, vérifiées et fusionnées par squash. CI et sécurité doivent concerner la base courante, sans contournement. Titres Conventional Commits et descriptions vides respectent la politique. Tags, métadonnées et fichiers publiés sont immuables ; toute correction exige une nouvelle version.

Le [guide ISO](../modules/iso/README.md) explique téléchargement, sommes et limites. La CI compare toute la configuration incluse avec les sources signées avant publication ; elle ne démarre pas l’image et ne prouve pas que l’installation copie OS dans la racine installée.

`v2.0/script/os-lua migration-report` inspecte tout le dépôt. `verify-full-lua` échoue tant que subsistent algorithmes Bash ou Ruby et composants anciens à remplacer ou retirer légitimement. [Architecture](../lua-architecture.md), [index](../README.md), [contribution](CONTRIBUTING.md) et [feuille de route](../../it/roadmap.md) décrivent responsabilités et progression réelle.
