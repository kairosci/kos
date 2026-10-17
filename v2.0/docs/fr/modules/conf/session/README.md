# Session graphique

L’adaptateur conserve les sources natives en lecture seule et génère la couche OS à partir de politiques externes. La configuration Hyprland préserve les écrans, les entrées, les thèmes et la gestion de l’inactivité. L’état géré est du JSON, jamais du Lua exécutable.

Le menu respecte les dimensions disponibles de l’écran et la largeur définie dans la politique. Le modèle des applications doit contenir de véritables fichiers desktop. Les messages sont traduits en six langues. Paramètres est une seule application pour le réseau, Bluetooth, l’audio et le bureau ; HyprMod reste disponible pour les réglages avancés du compositeur.

`make setup SCOPE=session` valide Lua et QML avant l’application, puis vérifie les erreurs de session. Le hook de mise à jour reconstruit les adaptateurs depuis les sources actuellement installées.
