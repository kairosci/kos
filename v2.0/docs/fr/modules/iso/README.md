# Image ISO

Le composant reconstruit la dernière image stable de la base prise en charge en ajoutant tout le dépôt suivi dans `/opt/os` et l’icône KMono cyan dans `/usr/share/pixmaps/os.png`. L’empreinte amont est vérifiée avant modification ; sa signature ne couvre pas l’image reconstruite. Les versions publiées sont immuables : corrections et nouveaux fichiers nécessitent une nouvelle version.

Les publications contiennent l’ISO divisée en parties, `os-vX.Y.iso.sha256` et les assistants `download-release.sh` et `download-release.ps1`. Bash nécessite curl, jq et sha256sum ; PowerShell prend en charge Windows PowerShell 5.1 et PowerShell 7. Tous deux téléchargent, assemblent et vérifient SHA-256 avant publication dans le répertoire courant, sans écraser les destinations existantes. Un tag explicite peut être choisi ; sinon la dernière version est utilisée.

Les temporaires privés se trouvent dans le répertoire de destination, jamais dans le `/tmp` en mémoire. Les parties sont ajoutées à l’image puis supprimées une par une : prévoir l’ISO entière plus une partie. Changer de répertoire avant l’exécution pour choisir la destination. Télécharger et lire le script avant exécution est préférable.

La CI extrait `/opt/os` de l’image finie et compare chaque fichier au dépôt matérialisé au commit signé du tag. Toute différence bloque la publication. Ce contrôle ne démarre ni n’installe l’ISO ; les assistants de téléchargement vérifient l’empreinte, pas le contenu du dépôt.

La surcouche ne reconstruit pas la racine live compressée et n’oblige pas l’installateur à copier la configuration. Après installation, copier `opt/os` du support vers un stockage persistant puis y lancer `make setup`. La base de bureau actuellement prise en charge reste nécessaire.

`make iso` construit localement avec la surcouche du composant ; cache et téléchargements amont utilisent le cache XDG. La publication exige un nouveau tag signé `vX.Y` depuis un commit revu et fusionné. Un échec avant publication permet de relancer ISO avec le même tag ; une publication existante ne sera jamais remplacée.

GRUB reste un candidat séparé, non confirmé comme chemin de démarrage effectif sur cette machine. Limine est conservé jusqu’à un essai réel. Le chemin pris en charge exige UEFI et une ESP sans ambiguïté, préserve chiffrement et paramètres des snapshots et inclut la récupération Snapper. Les mesures TPM n’équivalent ni à Secure Boot signé ni au contrôle d’empreintes propre à Limine.
