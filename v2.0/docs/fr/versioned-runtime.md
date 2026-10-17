# Structure versionnée

[Italiano](../it/versioned-runtime.md) · [English](../en/versioned-runtime.md) · [Français](versioned-runtime.md)

`v1.0/` conserve à la racine du dépôt l’archive Bash d’origine et sa somme de contrôle immuable. Elle ne sert jamais d’entrée exécutable. `v2.0/` est l’unique racine active et restera le conteneur des prochaines versions ; une publication ne crée pas une nouvelle copie des sources.

Le code Lua réside dans `src/core/` et `src/component/`, les données dans `data/`, les lanceurs indispensables dans `script/`, les tests dans `tests/` et la documentation dans `docs/it/`, `docs/en/` et `docs/fr/`. Le provisioning Bash encore nécessaire reste dans `scripts/`, `hooks/` et `modules/` de cette même arborescence. Le déplacement ne valide pas une migration Lua.

La racine du dépôt conserve les métadonnées natives requises par Git et GitHub et les liens d’entrée pour Make, les documents et les agents. GitHub exige de vrais fichiers dans `.github/workflows/` et sa configuration Dependabot dans `.github/` ; des liens empêcheraient leur découverte. Les politiques JSON du dépôt sont dans `v2.0/data/repository/`. Les anciens alias de code et de données à la racine sont supprimés.

`make test` et `make setup` fonctionnent depuis la racine du dépôt ou `v2.0/`. Seule la pipeline setup applique les changements système. Les commandes directes utilisent le préfixe `v2.0/`. Les bundles installés conservent leurs répertoires internes `src`, `data` et `script`.

`v2.0/script/os-lua migration-report` inspecte tout le dépôt, y compris les nouveaux fichiers et les lanceurs sans extension. `verify-full-lua` échoue tant que des algorithmes shell ou composants anciens restent actifs. La [feuille de route](../it/roadmap.md) conserve l’état réel ; des tests verts sur les composants remplacés ne prouvent pas une migration complète.
