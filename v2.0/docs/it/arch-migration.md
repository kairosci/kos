# Migrazione del runtime ad Arch

[Italiano](arch-migration.md) · [English](../en/arch-migration.md) · [Français](../fr/arch-migration.md)

Il sistema è già identificato come Arch Linux. L’obiettivo ulteriore è eliminare il runtime Omarchy conservando funzionalità equivalenti. Il launcher `os app` risolve browser, editor grafico, file manager e Impostazioni senza avviare o caricare Omarchy; questo risultato non dimostra la parità dell’intero desktop.

La selezione del browser segue XDG e, se vuota, l’associazione HTTPS. Editor e file manager seguono le associazioni MIME. Impostazioni apre `os.settings.desktop`. Le voci utente precedono quelle di sistema, inclusi gli override nascosti. Identità, argomenti e azione privata sono validati; Exec non viene interpretato. `os app browser --private` richiede l’azione dichiarata `new-private-window`, senza aprire una finestra normale se manca. Spazi e metacaratteri restano argomenti letterali; opzioni non supportate sono rifiutate. Usare percorsi assoluti per nomi che iniziano con un trattino.

`os app --resolve browser https://example.org` restituisce JSON senza avviare applicazioni. `make setup SCOPE=cli` installa il dispatcher, la policy e i cataloghi; non aggiorna pacchetti, cambia associazioni o riavvia servizi. Le applicazioni, gli strumenti XDG e UWSM devono essere già disponibili. Il launcher UWSM è descritto nel [manuale nativo](https://github.com/Vladimir-csp/uwsm/blob/master/man/uwsm-app.1.scd).

L’inventario in `data/component/platform/parity.json` distingue funzioni verificate da pacchetti semplicemente installati. Menu, avvio della sessione, notifiche, sfondo, singolo locker, directory di lavoro del terminale, tutte le opzioni storiche, aggiornamento e recupero richiedono sostituti e prove indipendenti.

Prima della rimozione servono una sessione di prova isolata, avvio a freddo, sospensione, ripresa e recupero verificati. Occorrono alternative per tutti i pacchetti disponibili soltanto nei repository attuali. Runtime, repository, chiavi, kernel e voci di recupero restano attivi finché queste condizioni non sono soddisfatte. La [transizione EFI](boot-transition.md) separa preparazione delle immagini e prove hardware.

## Passaggio dalla 1.9 alla 2.0

Prima dell'aggiornamento, salvare i dati personali e registrare snapshot attivo, kernel, voce firmware e stato dei servizi essenziali. Eseguire `make test`, `make verify` e `bash v2.0/scripts/test-os-compat.sh`; conservare gli esiti insieme all'output di `v2.0/script/os-lua migration-report` e `v2.0/script/os-lua arch-report`. Questi controlli non sostituiscono le prove hardware.

Applicare le modifiche soltanto con il setup privilegiato previsto dal repository. Mantenere Limine, kernel funzionante, repository e chiavi Omarchy, snapshot e voci EFI di recupero. Non eseguire il provisioning completo da uno snapshot o da una radice temporanea. In caso di avvio da uno snapshot Snapper, usare esclusivamente `make setup SCOPE=recovery`: salva i backup di configurazione nell'home persistente e ripristina lo snapshot avviato.

Registrare separatamente gli esiti di avvio a freddo, sblocco cifrato, sessione desktop, rete, audio, sospensione, ripresa e recupero. Per GRUB, installazione e selezione temporanea non equivalgono a un avvio verificato: conservare Limine fino al completamento di tutte le prove. Non azzerare la cronologia snapshot prima di aver avviato la radice persistente e verificato il desktop ripristinato.

La 2.0 è pronta solo quando il report Lua non trova algoritmi Bash o Ruby attivi, l'assessment conferma le capacità indipendenti da Omarchy e ogni prova hardware richiesta ha un esito registrato. In caso contrario, mantenere la 1.9 e i percorsi di recupero.
