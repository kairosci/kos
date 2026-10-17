# Feuille de route Lua

Le [registre des états](../it/roadmap.md) constitue l’unique autorité pour l’achèvement des sprints. Ce guide décrit la feuille de route en français sans dupliquer les indicateurs d’état.

Conserver l’archive Bash vérifiée sous `v1.0/`, puis remplacer algorithmes et tests par des composants Lua dans `v2.0/src/`. Commandes, politique linguistique, catalogues, destinations des applications et règles de rendu appartiennent à `data/`. Les lanceurs essentiels appartiennent à `script/` ; les interfaces des plateformes conservent leur format natif.

Le parcours couvre les primitives du moteur, l’analyse et le rendu du démarrage chiffré, les configurations graphiques, le fond d’écran, Paramètres, les ressources de l’éditeur, les paquets, la sécurité, l’énergie, la maintenance, la vérification et la session. Remplacer les appelants installés après validation comportementale. `make setup` reste l’unique voie d’application.

L’installation du menu Herdr et de son raccourci Hyprland géré utilise désormais le composant d’application Lua et une portée dédiée de configuration. Le registre italien indique l’état actuel.

Le sprint final supprime les algorithmes shell et l’ancienne structure après remplacement équivalent. `migration-report` examine tout le dépôt, y compris les fichiers nouveaux et sans extension ; `verify-full-lua` échoue tant que des algorithmes historiques restent actifs. Déplacer des fichiers ou déléguer Bash depuis Lua ne suffit jamais.

L’indépendance Arch exige des preuves par capacité, un moteur autonome, démarrage à froid réel, veille, déverrouillage chiffré et récupération. Conserver Limine, noyaux fonctionnels et secours jusqu’à réussite. Tests et noms de paquets ne prouvent pas la parité matérielle. Les guides publics existent en it, en et fr ; instructions opérationnelles et licences gardent leur source canonique partagée.
