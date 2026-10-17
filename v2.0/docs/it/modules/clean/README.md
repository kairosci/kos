# Pulizia storica

Questo sottoprogetto conserva strumenti Bash di pulizia precedenti alla migrazione completa. Non è il percorso di applicazione ordinario del progetto: le modifiche al sistema devono passare da `make setup`. La presenza del codice non autorizza a eseguire separatamente gli script privilegiati.

La policy storica comprende cache pacman con due versioni conservate, pacchetti orfani, journal limitato a 200 MiB e due settimane, core dump di quattordici giorni, file temporanei di sette giorni e temporanei persistenti di quattordici giorni. Include manutenzione Flatpak e cache dei font. La pulizia delle home riguarda inoltre launcher obsoleti, miniature e cestino dopo trenta giorni.

Alcuni percorsi storici trattano configurazioni di applicazioni rimosse: prima di migrare o applicare tali operazioni occorre preservare i dati personali e verificarne la proprietà. L’assenza di un pacchetto non autorizza da sola la cancellazione del suo profilo. Questi algoritmi restano nel rapporto dei componenti non ancora migrati.
