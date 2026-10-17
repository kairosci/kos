# État et interface du bureau

`make setup SCOPE=desktop-health` réconcilie EasyEffects, le contrôle DNS et l’assistant clavier par la procédure privilégiée. Il publie d’abord des assistants compatibles, puis effectue la mise à jour complète prévue par la distribution. Il ne modifie pas le chargeur de démarrage. Après cette réconciliation, 145 contrôles réels ont réussi sur cette machine.

L’ancienne erreur du clavier provenait d’une divergence entre `locale_init` et `i18n_init`, pas d’une limite matérielle non appliquée. Le rétroéclairage était déjà au maximum observé. Assistants et catalogues doivent partager la même API sans fabriquer de résultat positif.

La politique visuelle HyprMod sépare JSON, CSS, icônes symboliques et correctif exact des sources fixées. Une structure inconnue est refusée. L’ancien environnement reste disponible ; la navigation s’adapte au seuil de largeur, ouvre la vraie page et conserve le retour. Marges et espacements sont cohérents ; l’enregistrement automatique est initialisé uniquement sans préférence personnelle.

La palette GTK remplace des couleurs validées tout en préservant géométrie native, focus, sélection et barres de défilement. Les CSS personnels et les interfaces Qt, Electron et web restent distincts : le style commun ne réécrit pas chaque application. `make setup SCOPE=interface` actualise GTK et HyprMod sans charger le preset audio ni redémarrer audio ou bureau. `PREVIEW_INTERFACE=1` ouvre aussi l’aperçu. Certaines applications GTK doivent être rouvertes.

Calendrier, météo et horloge sont des fenêtres normales du menu Outils du bureau. Paramètres est une application unique, sans sous-menu dupliqué ; Resources utilise `net.nokyan.Resources.desktop`. L’ancien widget horloge est désactivé et retiré. `make setup SCOPE=desktop-tools` publie atomiquement des fichiers complets et vérifie la session sans ajouter de verrouilleur, panneau ou service de notifications.
