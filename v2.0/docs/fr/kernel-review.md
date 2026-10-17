# Analyse du noyau

L’observation du 16 octobre 2026 relevait le noyau Omarchy 7.2.5 en cours et le noyau Arch standard 7.2.3 installé. Ces versions constituent un état historique, pas une recommandation d’installer d’anciennes versions. Le paquet officiel Arch `linux` est maintenu par la distribution et diffère d’une compilation directe de kernel.org.

Un noyau dit « pur » n’est pas automatiquement plus sûr. Mises à jour, configuration, modules, firmware et compatibilité du démarrage comptent. Le paquet officiel actualisé évite une chaîne de compilation personnelle, mais ne démontre pas la parité du système.

La présence d’i915, iwlwifi et NVMe ne prouve ni veille, hibernation, reprise, audio ni récupération. Secure Boot était désactivé. Conserver le noyau fonctionnel, Limine et les entrées de secours jusqu’à un essai réel du candidat avec chiffrement, démarrage à froid et restauration vérifiés.

L’inventaire Arch contient seize capacités à démontrer indépendamment : des paquets installés et des tests historiques réussis ne prouvent pas l’autonomie du bureau. L’analyse est en lecture seule ; le retrait d’Omarchy n’est pas encore implémenté. L’essai GRUB au prochain redémarrage n’autorise pas à interrompre la session active.
