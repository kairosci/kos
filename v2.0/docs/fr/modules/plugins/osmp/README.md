# OSMP

OSMP, identifié par `os.osmp`, est le plugin multimédia local. La version 1.5.0 doit correspondre entre le manifeste et le paquet. Le dépôt possède ses sources : aucune seconde copie distante ne doit être installée.

Le plugin utilise MPRIS avec des arguments `busctl` sans évaluer de commandes. Il prend en charge les contrôles disponibles, un historique en mémoire et les positions en microsecondes. Les contrôles indisponibles restent désactivés ; la recherche respecte les limites du morceau et le volume est restauré selon la politique.

La distribution contient seulement le moteur, le manifeste et la licence, jamais des liens vers la documentation. L’ancienne identité `krosci.omamp` est archivée. Le menu ouvre Celluloid dans une fenêtre normale sans activer l’ancien popup `os.media`.
