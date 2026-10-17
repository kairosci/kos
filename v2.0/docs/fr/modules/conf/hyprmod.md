# Paramètres avancés de Hyprland

HyprMod propose des contrôles GTK4 et libadwaita pour le compositeur, les écrans, le clavier, la souris, les raccourcis, les règles et les espaces de travail. Aperçu, modifications en attente, enregistrement et annulation évitent l’édition manuelle. Le fichier généré `~/.config/hypr/hyprland-gui.lua` est chargé après les valeurs gérées et conservé par l’installation. L’application Paramètres, également accessible par Super+virgule, regroupe réseau, Bluetooth et audio ; HyprMod reste le contrôle avancé du compositeur.

La source HyprMod 0.5.0 est fixée à `e148d221cc62edaa8d1b8ffac0f0a57edcb8e3c1`. Sources et wheels Python purs possèdent des empreintes SHA-256 dans le verrou. GTK, libadwaita, Cairo, PyGObject, le backend de compilation et uv proviennent de pacman. Python est le moteur de l’application, pas une substitution à l’implémentation Lua d’OS. Aucun script distant ni environnement pip global n’est modifié. L’environnement est recréé si le verrou ou Python système change.

`make setup SCOPE=settings` installe et valide la configuration préparée avant publication. Le correctif exact, les dimensions JSON, le CSS et les icônes symboliques suivent la palette. Les préférences explicites d’enregistrement automatique sont conservées. L’usage de la GUI autorise ses propres écritures, jamais des modifications directes des agents hors procédure.

Référence : [source fixée](https://github.com/BlueManCZ/hyprmod/tree/e148d221cc62edaa8d1b8ffac0f0a57edcb8e3c1).
