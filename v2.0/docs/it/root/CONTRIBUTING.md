# Contribuire

Le modifiche partono da un ramo dedicato e raggiungono main attraverso una pull request. Main è in sola lettura per il lavoro diretto. Aprire le issue GitHub in inglese come lingua predefinita. Aggiornare nello stesso cambiamento la documentazione pubblica in italiano, inglese e francese; le istruzioni operative condivise restano canoniche in inglese. Prima della pubblicazione eseguire `script/os-lua verify-documentation`. I commit sono firmati e seguono Conventional Commits: tipo, eventuale ambito, due punti e descrizione; nessun altro simbolo nel titolo. Le descrizioni delle PR restano vuote secondo il template del repository.

Implementare prima il cambiamento nel repository, con policy separate dagli algoritmi, messaggi nei sei cataloghi e documentazione pubblica in it, en e fr. Le istruzioni operative e le licenze mantengono la fonte canonica condivisa. Non aggiungere classi cosmetiche, soppressioni di errori o test che ripetano soltanto l’implementazione.

Prima della pubblicazione eseguire i controlli pertinenti e la suite richiesta; la CI e il SAST devono risultare verdi sulla base più recente. Le modifiche live passano esclusivamente da `make setup`, mai da copie manuali o riavvii di servizi esterni alla pipeline. Conservare dati personali, recupero, cifratura e funzionalità del desktop.

Il merge usa squash con descrizione vuota e rimozione del ramo quando tutti i controlli sono soddisfatti. Release, tag e asset pubblicati sono immutabili: una correzione richiede una nuova versione, senza riutilizzare o spostare tag esistenti.
