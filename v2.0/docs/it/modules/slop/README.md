# Rimozione opzionale degli strumenti AI

Il sottoprogetto storico richiede una scelta esplicita. Senza opzione mostra il piano; l’esecuzione privilegiata richiede conferma tramite `--yes`. La pipeline principale non deve raggiungerlo incidentalmente dalle fasi di rimozione dei pacchetti.

La policy riguarda servizi di osservazione dei crash, integrazioni degli agenti e launcher AI autonomi. Non rimuove gli strumenti CLI gestiti da mise, Tensaku, editor, shell o temi. Gli interventi per utente richiedono il suo bus di sessione reale. Come ogni modifica live, l’applicazione da parte degli agenti deve passare dalla pipeline privilegiata, conservando i dati personali.
