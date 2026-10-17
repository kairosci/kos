# Installation d’OSMP

L’installateur publie le plugin local sous l’identifiant `os.osmp`. Avant l’activation, il valide un contenu autonome limité aux sources d’exécution, au manifeste et à la licence canonique. Les liens de documentation sont exclus ; aucune autre copie du plugin n’est téléchargée.

L’intégration réconcilie le catalogue natif et archive l’ancienne installation `krosci.omamp`. Les versions du manifeste et du paquet doivent correspondre. Le popup retiré `os.media` reste désactivé ; le menu ouvre Celluloid comme application normale.

L’installateur est désormais en Lua dans `src/component/media/plugin.lua`. Les sources natives résident dans `src/component/media/osmp/src/`, les manifestes et métadonnées dans `data/component/media/osmp/`. `make setup SCOPE=lua-applications` réconcilie le registre applicatif. Collisions, destinations redirigées et sauvegardes symboliques sont refusées avant publication ; un échec de validation conserve le moteur installé.
