# Migrazione del runtime ad Arch

[Italiano](arch-migration.md) · [English](../en/arch-migration.md) · [Français](../fr/arch-migration.md)

Il sistema è già identificato come Arch Linux. L’obiettivo ulteriore è eliminare il runtime Omarchy conservando funzionalità equivalenti. Il launcher `os app` risolve browser, editor grafico, file manager e Impostazioni senza avviare o caricare Omarchy; questo risultato non dimostra la parità dell’intero desktop.

La selezione del browser segue XDG e, se vuota, l’associazione HTTPS. Editor e file manager seguono le associazioni MIME. Impostazioni apre `os.settings.desktop`. Le voci utente precedono quelle di sistema, inclusi gli override nascosti. Identità, argomenti e azione privata sono validati; Exec non viene interpretato. `os app browser --private` richiede l’azione dichiarata `new-private-window`, senza aprire una finestra normale se manca. Spazi e metacaratteri restano argomenti letterali; opzioni non supportate sono rifiutate. Usare percorsi assoluti per nomi che iniziano con un trattino.

`os app --resolve browser https://example.org` restituisce JSON senza avviare applicazioni. `make setup SCOPE=cli` installa il dispatcher, la policy e i cataloghi; non aggiorna pacchetti, cambia associazioni o riavvia servizi. Le applicazioni, gli strumenti XDG e UWSM devono essere già disponibili. Il launcher UWSM è descritto nel [manuale nativo](https://github.com/Vladimir-csp/uwsm/blob/master/man/uwsm-app.1.scd).

L’inventario in `modules/platform/arch/data/parity.json` distingue funzioni verificate da pacchetti semplicemente installati. Menu, avvio della sessione, notifiche, sfondo, singolo locker, directory di lavoro del terminale, tutte le opzioni storiche, aggiornamento e recupero richiedono sostituti e prove indipendenti.

Prima della rimozione servono una sessione di prova isolata, avvio a freddo, sospensione, ripresa e recupero verificati. Occorrono alternative per tutti i pacchetti disponibili soltanto nei repository attuali. Runtime, repository, chiavi, kernel e voci di recupero restano attivi finché queste condizioni non sono soddisfatte. La [transizione EFI](boot-transition.md) separa preparazione delle immagini e prove hardware.
