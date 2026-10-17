# Contribuer

Les changements partent d’une branche dédiée et rejoignent main par pull request. Main reste en lecture seule pour le travail direct. Créer les issues GitHub en anglais par défaut. Mettre à jour la documentation publique en italien, anglais et français dans le même changement ; les instructions machine partagées restent canoniques en anglais. Exécuter `script/os-lua verify-documentation` avant publication. Les commits sont signés et suivent Conventional Commits : type, portée éventuelle, deux-points et description ; aucun autre symbole dans le titre. Les descriptions des PR restent vides conformément au modèle du dépôt.

Préparer d’abord les changements dans le dépôt, avec politiques séparées des algorithmes, messages dans les six catalogues et documentation publique en it, en et fr. Instructions opérationnelles et licences conservent leur source canonique partagée. Ne pas ajouter de classes cosmétiques, d’erreurs masquées ou de tests recopiant l’implémentation.

Avant publication, exécuter les contrôles pertinents et la suite requise ; CI et SAST doivent réussir sur la base la plus récente. Les changements réels passent uniquement par `make setup`, jamais par copie manuelle ou redémarrage de service hors procédure. Conserver données personnelles, récupération, chiffrement et fonctions du bureau.

La fusion utilise squash avec description vide et suppression de branche après réussite de tous les contrôles. Publications, tags et fichiers publiés sont immuables : toute correction exige une nouvelle version, sans déplacer ni réutiliser un tag existant.
