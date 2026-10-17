# Aperçus des thèmes

La régénération applique chaque thème réel et capture l’écran complet, avec le shell, le fond et des fenêtres témoins Zed et Nautilus. Géométrie et positions proviennent du canvas observé, sans décalages fixes. Le thème, le fond, l’espace de travail et l’état des notifications sont restaurés même en cas d’erreur.

Les images sont normalisées à la géométrie commune prévue, avec canal alpha, profondeur 8 et densité 72. L’opération est idempotente et conserve l’original pour restauration. Les exclusions appartiennent au fichier de politique des thèmes ; les algorithmes ne contiennent aucun nom de thème prédéfini.

Le hook root après mise à jour réconcilie la normalisation. Une capture de fenêtres témoins ne prouve pas chaque application : la vérification inclut le thème natif et une seule instance Zed effectivement actualisée.
