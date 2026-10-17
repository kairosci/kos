# Anteprime dei temi

La rigenerazione applica ogni tema effettivo e cattura l’intero monitor, includendo shell, sfondo e finestre campione di Zed e Nautilus. Geometria e posizioni derivano dal canvas reale, non da offset fissi. Il tema originario, lo sfondo, il workspace e lo stato delle notifiche vengono ripristinati anche in caso di errore.

Le immagini vengono normalizzate alla geometria uniforme prevista, con canale alfa, profondità 8 e densità 72. L’operazione è idempotente e conserva l’asset stock per il ripristino. Le esclusioni appartengono al file di policy dei temi; gli algoritmi non contengono nomi di temi predefiniti.

L’hook root successivo agli aggiornamenti riconcilia la normalizzazione. Uno screenshot ottenuto da finestre campione non dimostra la correttezza di ogni applicazione: la verifica deve includere il tema nativo e una singola istanza Zed effettivamente aggiornata.
