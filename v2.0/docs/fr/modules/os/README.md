# Commande os

Le répartiteur Lua appartient à `src/component/cli/`, ses politiques et rôles à `data/component/cli/`. `script/os` est uniquement un lanceur essentiel. `os app browser`, `editor`, `files` et `settings` résolvent les fichiers desktop et démarrent UWSM sans charger Omarchy. Navigateur, éditeur et fichiers suivent les valeurs XDG ; settings désigne l’application Paramètres. `os app --resolve settings` affiche le résultat sans ouvrir de fenêtre.

Le parseur traite les arguments littéralement, vérifie les actions privées déclarées et respecte les lanceurs masqués. Les autres groupes restent délégués au moteur natif avec leurs arguments et code de sortie. Le contexte de session est complété uniquement s’il manque et existe réellement. Ce résultat ne prouve pas l’indépendance du bureau vis-à-vis d’Omarchy.

`os changelog` lit le registre complet ou la version demandée, avec erreur visible si le fichier ou la version manque. `make setup SCOPE=cli` publie un paquet validé et des liens système et utilisateur, en préservant les contenus personnels. Les tests couvrent XDG isolé, arguments hostiles, délégation, codes de sortie, idempotence et rejet des sources invalides.
