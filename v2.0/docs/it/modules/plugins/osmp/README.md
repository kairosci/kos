# OSMP

OSMP, identificato da `os.osmp`, è il plugin multimediale locale. La versione 1.5.0 deve restare coerente tra manifest e pacchetto. I sorgenti sono posseduti dal repository: non installare una seconda copia remota.

Il plugin usa MPRIS tramite argomenti `busctl` senza valutare comandi. Supporta i controlli di riproduzione disponibili, una cronologia in memoria e posizioni in microsecondi. I controlli non supportati rimangono disabilitati; la ricerca rispetta i limiti del brano e il volume viene ripristinato secondo la policy.

La distribuzione include soltanto runtime, manifest e licenza, mai symlink alla documentazione. La precedente identità `krosci.omamp` viene archiviata. Il menu apre Celluloid come finestra normale e non abilita il popup ritirato `os.media`.
