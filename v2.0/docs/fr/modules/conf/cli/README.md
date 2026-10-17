# Aide et thèmes du terminal

`make cli` applique le composant Lua par `make setup SCOPE=terminal`.

`src/component/terminal/` gère l’aide, la palette et l’installation. Les guides des outils existent dans six langues sous `data/component/terminal/help/`. Les règles, modèles et données de shell restent séparés des algorithmes. L’adaptateur Bash expose seulement `helper` au shell interactif ; le hook du thème lance seulement Lua.

L’installateur conserve le contenu et les permissions du shell, publie un seul bloc géré et archive l’ancien helper avec des permissions privées. FZF utilise les couleurs validées du thème réel. LazyGit utilise les couches natives de `LG_CONFIG_FILE` : la configuration personnelle reste intacte et la palette générée est ajoutée une seule fois. Les listes explicites sont conservées. Une palette invalide, une sauvegarde redirigée ou un bloc incomplet interrompt la publication avant le remplacement de l’intégration du shell.

Exécuter `lua -E tests/lua/run.lua "$PWD" terminal` depuis `v2.0/` pour les tests isolés.
