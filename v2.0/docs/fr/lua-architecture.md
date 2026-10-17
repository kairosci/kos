# Architecture Lua

[Italiano](../it/lua-architecture.md) · [English](../en/lua-architecture.md) · [Français](lua-architecture.md)

Les chemins sont relatifs à l’arborescence active `v2.0/`. `src/main.lua` charge les composants et transmet les arguments à `src/component/runtime/application.lua`. Les objets avec état utilisent des constructeurs explicites et des métatables ; les utilitaires purs restent des fonctions.

`src/core/` gère JSON, fichiers, INI, chemins XDG, processus natifs, catalogues de messages et publication atomique. Les algorithmes métier appartiennent à `src/component/` : validation EFI et génération GRUB, préférences des applications, rendu et installation des fonds, persistance des paramètres et calcul des ressources.

`data/core/` définit commandes, dépendances, priorité des langues, chemins et composition du runtime. `data/component/` contient les politiques et ressources des domaines ; `data/catalog/` contient les six langues d’exécution. Les données ne sont jamais évaluées par `load`, `loadfile`, `dofile` ou un interpréteur shell. YAML, shell et texte natifs peuvent être des ressources littérales. Toute modification structurée exige un analyseur testé pour le format concerné.

`script/os-lua` déduit sa racine de son emplacement, lit les données de démarrage externes et lance Lua sans traitement de l’environnement de démarrage. Toute modification système passe par `make setup`. Les interfaces natives conservent leur format.

Les algorithmes conservés dans `scripts/`, `hooks/` et `modules/` restent à migrer. L’archive immuable `v1.0/` n’est jamais un moteur d’exécution. `migration-report` inspecte tout le dépôt Git et `verify-full-lua` échoue tant que subsistent des algorithmes ou composants anciens. Déplacer des fichiers ou appeler Bash depuis Lua ne démontre pas leur équivalence.

Les bundles installés sont immuables. Sources et JSON sont validés avant le remplacement atomique du lien `current`. Le manifeste détecte également les fichiers supprimés. Une publication échouée conserve le bundle précédent et supprime le répertoire temporaire ; des données identiques réutilisent le bundle existant. Implémentation, installation réelle et validation matérielle sont des résultats distincts, suivis dans la [feuille de route](../it/roadmap.md).
