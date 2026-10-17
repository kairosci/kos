# Revisioni delle pull request

La revisione del 16 ottobre 2026 ha verificato le PR 113 e 114, limitate alle revisioni fissate delle azioni artifact per ISO. I riferimenti corrispondono alle release ufficiali download v8.0.2 e upload v7.0.2 su Node 24. Input e directory previsti restano compatibili. Entrambe sono state mergiate squash, con descrizione vuota e ramo eliminato, dopo controlli aggiornati sulla base risultante. Il workflow di pubblicazione ISO non è stato eseguito durante quella revisione.

La PR 117 ha sostituito GNOME Settings con HyprMod, preservando il file generato dalla GUI. La migrazione dei percorsi controlla tutte le collisioni prima di spostare dati e rifiuta destinazioni redirette. Lo sfondo usa palette e geometria validate per la cache e archivia le selezioni stock fuori dal catalogo attivo. Dipendenze fissate con hash e validazione della configurazione precedono la pubblicazione. Sono passate 1803 asserzioni in 42 suite e i controlli remoti aggiornati. Merge squash `318f50c0` con descrizione vuota.

La PR 64 non risultava pronta: ricomponeva un pacchetto eliminando un file senza rigenerare `.MTREE`, mantenendo un nome che oscurava la provenienza dell’artefatto. Inoltre il vecchio script di release non era il percorso ISO attuale. Occorrono un riproduttore corrente e metadati coerenti prima di approvarla.

I wrapper cosmetici di classe sono stati rimossi; le funzioni hanno nomi descrittivi senza cifre. I test isolano XDG e il runtime nativo per non raggiungere la sessione reale. ImageMagick e ripgrep sono dipendenze esplicite della CI. Questa revisione documenta cambiamenti e percorsi verificati, non l’assenza di difetti in ogni funzione del repository.
