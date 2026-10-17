# Paramètres

[Italiano](../it/settings.md) · [English](../en/settings.md) · [Français](settings.md)

`os app settings`, également accessible par Super et virgule, ouvre une seule application en mosaïque regroupant bureau Hyprland, réseau, Bluetooth, audio et alimentation. Elle apparaît dans Apps, sans entrée dans Outils du bureau. Les anciens rôles `os app network`, `os app bluetooth` et `os app audio` ouvrent la même application.

Le bureau lit les valeurs du compositeur et propose 26 préférences : bordures, arrondis, sensibilité, répétition des touches, animations, flou et ses paramètres, ombres, opacité, pavé tactile, réveil de l’écran, disposition des fenêtres et clavier. Les modifications sont validées sur une copie avant publication du module géré `hypr/os-settings.lua`. L’état est un JSON privé ; les fichiers personnels sont préservés. Un rechargement échoué restaure le module précédent. Les écritures sont sérialisées et les erreurs restent visibles. Les fonctions avancées de HyprMod ne sont pas toutes reprises ; HyprMod reste installé.

Le réseau utilise l’intégration NetworkManager native de Quickshell pour Ethernet, Wi-Fi, connexion, déconnexion, suppression des profils et mots de passe WPA personnels. Les secrets sont transmis directement au service, jamais aux arguments des processus ou aux catalogues. VPN, configuration IP manuelle et authentification d’entreprise ne sont pas modifiables ici ; les profils existants restent conservés.

Bluetooth utilise BlueZ pour l’alimentation, la recherche, l’association et la connexion. Les demandes de code PIN dépendent toujours de l’agent existant. L’audio utilise PipeWire pour les périphériques par défaut, le volume et la sourdine. Les connexions Wi-Fi, associations Bluetooth et comportements audio réels exigent des essais matériels supplémentaires.

L’alimentation lit la batterie via UPower et règle les délais de verrouillage et d’économiseur. Lua publie atomiquement le JSON natif de session, en conservant les autres préférences et l’unique gestionnaire d’inactivité. Les seuils de charge restent la responsabilité de la politique matérielle.

Les algorithmes Lua résident dans `src/component/settings/`, les politiques dans `data/component/settings/`, les contrôles natifs dans `src/component/settings/qml/` et le lanceur dans `script/os-settings`. `src/core/bundle.lua` possède l’empaquetage immuable partagé. Le provisioning passe par `make setup SCOPE=settings` ; les choix de l’utilisateur sont enregistrés par les services natifs et le moteur Lua.

Références : [réseau Quickshell](https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/Networking/), [identifiants Wi-Fi](https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/WifiNetwork/).
