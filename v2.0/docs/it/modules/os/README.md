# Comando os

Il dispatcher Lua vive in `src/component/cli/`, con policy e ruoli separati sotto `data/component/cli/`. `script/os` è soltanto lo starter essenziale. `os app browser`, `editor`, `files` e `settings` risolvono file desktop e avviano UWSM senza caricare il runtime Omarchy. Browser, editor e file seguono i default XDG; settings identifica l’app Impostazioni. `os app --resolve settings` mostra il risultato senza aprire finestre.

Il parser tratta gli argomenti come dati letterali, verifica le azioni private dichiarate e rispetta i launcher nascosti. Gli altri gruppi vengono ancora delegati al runtime nativo, conservando argomenti e codice di uscita. Il contesto della sessione viene completato solo se mancante e realmente disponibile. Questo risultato non prova l’indipendenza del desktop da Omarchy.

`os changelog` legge l’intero registro o la sezione della release richiesta, con errore visibile per file o versione mancanti. `make setup SCOPE=cli` pubblica un bundle validato, un collegamento di sistema e quelli per utente, preservando i contenuti estranei. I test coprono profili XDG isolati, argomenti ostili, delega, codici di uscita, idempotenza e mancata attivazione di sorgenti non validi.
