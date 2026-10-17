# Transition de démarrage EFI

[Italiano](../it/boot-transition.md) · [English](../en/boot-transition.md) · [Français](boot-transition.md)

La machine observée démarre avec Limine, entrée firmware 0001. Son ESP FAT est montée sur `/boot` ; la racine Btrfs chiffrée utilise des arguments propres à la racine, au resume et à AppArmor. Ces observations ne garantissent pas le fonctionnement d’autres matériels.

`make setup SCOPE=boot-assessment` enregistre montages, firmware, périphériques, configurations, presets et images dans le répertoire privé root `/var/lib/os/boot-assessment`. Lua valide les exécutables PE et leurs sommes BLAKE2b. Images absentes, chemins hors ESP, champs dupliqués, protocoles incompatibles et altérations d’intégrité sont refusés. Les arguments de chaque snapshot restent distincts. L’inventaire ne modifie pas les préférences du firmware.

`make setup SCOPE=grub-trial` prépare un candidat séparé avec `--no-nvram`. L’enregistrement utilise `--create-only` ; BootOrder et Limine sont conservés. Le menu réutilise les mêmes images EFI vérifiées et leurs arguments de chiffrement, resume et sécurité. Les politiques et l’analyseur appartiennent à `data/component/boot/` et `src/component/boot/` ; `grub-script-check` valide avant publication. L’inventaire Limine demeure une dépendance transitoire.

Le premier essai matériel est revenu à Limine. Secure Boot était désactivé et l’ancien candidat utilisait un préfixe disque implicite. `SCOPE=grub-repair` reconstruit uniquement le candidat autonome avec ses modules incorporés et recherche de l’ESP par UUID. Cela supprime la dépendance aux modules externes, sans établir la cause de l’échec ni prouver un démarrage réussi.

Après le choix de l’utilisateur, `SCOPE=boot-trial-select` valide inventaire et menu, identifie le candidat unique par libellé et chemin EFI, puis définit uniquement BootNext en vérifiant BootOrder inchangé. La session ne redémarre pas. Avant de modifier le défaut, vérifier démarrage, déchiffrement, racine persistante, graphisme, réseau, audio, suspension, reprise et récupération. Le noyau courant, Limine et l’image EFI de secours restent disponibles.

`SCOPE=boot-appearance` choisit Plymouth textuel et régénère les UKI courantes avec les outils natifs. Il vérifie d’abord une sauvegarde persistante complète de l’ESP, puis conserve toutes les paires image/arguments, même lorsque plusieurs snapshots partagent une image. Il contrôle PE, sommes et thème textuel sans images Omarchy dans les initrd courants. Un échec restaure l’ESP et la configuration précédentes ; les anciens snapshots restent intacts.

Une vérification ultérieure a trouvé des sommes périmées dans le menu natif après une régénération réussie. La réconciliation accepte uniquement les images correspondant au manifeste privé déjà validé et aux mêmes paires image/arguments. Elle valide le menu complet avant publication atomique et refuse toute dérive inconnue. Le processus externe responsable des anciennes sommes n’est pas identifié.

Références : [chainloader GRUB](https://www.gnu.org/software/grub/manual/grub/html_node/chainloader.html), [configuration Limine](https://github.com/limine-bootloader/limine/blob/v12.x/CONFIG.md). Syntaxe et intégrité ne remplacent pas un essai réel de démarrage et de déchiffrement.
