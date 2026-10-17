# Protection historique des aperçus

Ce sous-projet conserve l’intégration historique avec Yazi pour masquer les aperçus de chemins sensibles. Yazi est retiré du bureau actuel : aucun lanceur, hook ou assistant géré ne doit le réactiver. Les données personnelles restent conservées.

L’ancienne politique utilisait dix-neuf motifs de chemins et des signaux d’inactivité pour nettoyer les aperçus. Il s’agit d’une protection visuelle, pas d’un chiffrement, d’un contrôle d’accès ou d’une défense contre la lecture directe des fichiers. Les exemples historiques ne justifient jamais de placer des mots de passe dans l’environnement ou les arguments des processus.

Un remplacement futur doit définir son périmètre de confiance, vérifier son comportement réel et respecter l’unique verrouilleur de session. La migration ne doit pas transformer un composant retiré en dépendance active.
