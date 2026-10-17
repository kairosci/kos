# Revues des pull requests

La revue du 16 octobre 2026 a vérifié les PR 113 et 114, limitées aux révisions fixées des actions artifact pour ISO. Elles correspondent aux versions officielles download v8.0.2 et upload v7.0.2 sur Node 24. Les entrées et répertoires attendus restent compatibles. Les deux PR ont été fusionnées par squash, avec description vide et suppression de branche, après de nouveaux contrôles sur la base actualisée. La publication ISO n’a pas été exécutée pendant cette revue.

La PR 117 a remplacé GNOME Settings par HyprMod tout en conservant le fichier généré. La migration vérifie toutes les collisions avant déplacement et refuse les destinations redirigées. Le fond utilise palette et géométrie validées pour son cache et archive les choix d’origine hors du catalogue actif. Dépendances fixées avec empreintes et validation précèdent la publication. Les 1803 assertions de 42 suites et les contrôles distants actualisés ont réussi. Fusion squash `318f50c0`, description vide.

La PR 64 n’était pas prête : elle reconstruisait un paquet après retrait d’un fichier sans régénérer `.MTREE`, avec un nom masquant la provenance. Son ancien script de publication n’était pas le chemin ISO actuel. Un cas reproductible actuel et des métadonnées cohérentes sont nécessaires avant approbation.

Les enveloppes de classes purement cosmétiques ont été retirées ; les fonctions portent des noms descriptifs sans chiffres. Les tests isolent XDG et le moteur natif pour ne pas atteindre la session réelle. ImageMagick et ripgrep sont des dépendances CI explicites. Cette revue décrit les changements et chemins vérifiés, sans certifier chaque fonction du dépôt.
