# Stato e interfaccia del desktop

`make setup SCOPE=desktop-health` riconcilia EasyEffects, il servizio di verifica DNS e l’helper della tastiera attraverso la pipeline privilegiata. Pubblica prima helper compatibili, poi esegue l’aggiornamento completo previsto dalla distribuzione. Non modifica il bootloader. Dopo la riconciliazione sono passati 145 controlli live su questa macchina.

Il precedente errore della tastiera era una divergenza tra `locale_init` e `i18n_init`, non un limite hardware mancato. L’illuminazione era già al massimo effettivo. Helper e cataloghi devono usare la stessa API; i controlli non devono inventare un risultato positivo.

La policy visuale HyprMod separa JSON, CSS, icone simboliche e patch esatta sui sorgenti fissati. Una struttura inattesa viene rifiutata. L’ambiente precedente resta disponibile; la navigazione si adatta al breakpoint, apre la pagina effettiva e permette di tornare indietro. Margini e spaziature sono coerenti; il salvataggio automatico viene inizializzato soltanto se manca una scelta personale.

La palette GTK sostituisce colori validati conservando geometria nativa, focus, selezione e scrollbar. CSS personali, layout Qt, Electron e web restano distinti: lo stile condiviso non riscrive ogni interfaccia. `make setup SCOPE=interface` aggiorna GTK e HyprMod senza caricare il preset audio o riavviare audio e desktop. `PREVIEW_INTERFACE=1` apre anche l’anteprima. Alcune applicazioni GTK richiedono una riapertura.

Calendario, meteo e orologio sono finestre normali dal menu Strumenti desktop. Impostazioni è un’app unica per i controlli di sistema e non un sottomenu duplicato; Resources usa `net.nokyan.Resources.desktop`. Il vecchio widget orologio è disabilitato e ritirato. `make setup SCOPE=desktop-tools` pubblica atomicamente file completi e verifica la sessione senza introdurre un secondo locker, pannello o demone delle notifiche.
