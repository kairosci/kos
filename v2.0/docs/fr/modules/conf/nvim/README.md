# Neovim et LazyVim

L’éditeur du terminal utilise Neovim et le LazyVim fourni par les paquets. La procédure initialise uniquement les configurations absentes et vérifie les extensions en cache ; elle ne remplace pas silencieusement une configuration existante inconnue. La souris reste utilisable.

F1 affiche l’aide, Ctrl+S enregistre, Ctrl+Q demande confirmation si nécessaire, Ctrl+P ouvre les fichiers, Ctrl+F recherche, F2 ouvre l’explorateur et F3 recherche dans le projet. F4 ou `:Settings` ouvrent la configuration ; Espace affiche les commandes disponibles. Ces commandes ne constituent pas une application graphique de paramètres système.

La configuration reste en Lua. Les configurations locales exécutables des projets et les modelines sont désactivées. Mettre à jour des extensions ou télécharger des outils de langage introduit du code dans la session de l’utilisateur et exige une revue des dépendances.
