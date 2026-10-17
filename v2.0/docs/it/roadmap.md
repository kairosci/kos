# Migrazione integrale a Lua

Il linguaggio obiettivo è esclusivamente Lua. Ruby viene ritirato. La versione in sviluppo è contenuta in `v2.0/`, con algoritmi in `src/`, componenti in `src/component/`, dati in `data/`, ingressi essenziali in `script/` e test in `tests/lua/`. I percorsi successivi sono relativi a questa radice, salvo quelli legacy. Le applicazioni native mantengono i formati di interfaccia richiesti dalla piattaforma.

| Sprint | Risultato richiesto | Stato |
| --- | --- | --- |
| Conservazione | Backup Bash verificabile in `v1.0`, escluso da installazione e discovery | Completato |
| Fondazioni Lua | Processi, JSON, lettura file, cataloghi e pubblicazione atomica senza Ruby | Applicato e verificato con test automatici e controllo live |
| Avvio Lua | Parser EFI, BLAKE2b, parametri cifratura e resume, generazione e pubblicazione GRUB | Applicato come candidato; collaudo hardware al prossimo riavvio |
| Componenti desktop | Riscrittura dei produttori di configurazione e degli hook in `src/component/`, dati centralizzati | Quindici applicazioni, componente sfondi e pianificazione risorse editor migrati; altri produttori da sostituire |
| Provisioning Lua | Pacchetti, sicurezza, alimentazione, manutenzione e verifica tramite componenti Lua | Da implementare |
| Consolidamento struttura | Eliminazione di `modules/` e degli algoritmi Bash attivi, soli ingressi necessari in `script/` | Da completare dopo le sostituzioni |
| Parità Arch | Runtime indipendente, prova avvio, sospensione, recupero e inventario delle funzioni | Verifica hardware aperta |

I primi componenti vengono sostituiti insieme ai loro chiamanti installati. I cataloghi canonici si trovano in `data/catalog/`; comandi nativi, selezione lingua e layout del runtime sono policy in `data/core/`; struttura del menu e policy di avvio sono in `data/component/boot/`. Configurazioni non valide interrompono il flusso prima della pubblicazione. Nessun dato viene eseguito come codice.

La pipeline `make setup` resta l'unico percorso di applicazione al sistema. La migrazione è completa soltanto quando non rimangono algoritmi Bash o Ruby attivi: spostare i vecchi file o chiamarli da Lua non soddisfa il requisito. Il collaudo del prossimo avvio resta distinto dai test automatici.

Il catalogo sfondi espone una sola immagine con il logo e la palette del tema. La policy vive in `data/component/wallpaper/`; il componente Lua archivia le varianti precedenti e gli sfondi personali aggiuntivi fuori dal selettore nativo. Rendering, geometria, cache e installazione del runtime sfondi sono implementati in Lua; gli ingressi shell residui inoltrano soltanto al runtime.

Il criterio di completamento è eseguibile: `script/os-lua migration-report` elenca algoritmi shell residui e file nella struttura legacy; `script/os-lua verify-full-lua` fallisce finché rimangono. Gli starter essenziali ammessi sono verificati per contenuto tramite digest BLAKE2b. Il report include anche file nuovi e script senza estensione; non usa una percentuale dedotta dal numero di file.

La parità completa con la versione Bash non è raggiunta. Rimangono da riscrivere provisioning dei pacchetti, sicurezza, alimentazione, manutenzione, verifica, integrazioni di sessione e produttori di configurazione residui. Gli ingressi Make e documentazione in radice sono collegamenti; gli alberi del codice vivono soltanto in `v2.0/`. Gli inventari eseguiti dalla radice e da `v2.0/` devono coincidere e includere il provisioning Bash; `verify-full-lua` deve continuare a fallire finché questi algoritmi sono attivi.

Lo sprint Impostazioni unificate introduce quattro sezioni native e un backend Lua per undici preferenze Hyprland. La validazione e i test automatici coprono pubblicazione, isolamento dello stato e ripristino. Restano aperti controlli avanzati HyprMod, editing IP e VPN, autenticazione enterprise e agente PIN Bluetooth integrato; le prove di connessione e associazione hardware non sono sostituite dai test grafici isolati.

Lo sprint successivo porta Impostazioni a cinque sezioni, 26 preferenze Hyprland e due timer della sessione. Impostazioni resta un’applicazione nel catalogo Apps, senza voce in Strumenti desktop. Le descrizioni dei richiami al menu usano OS. Resources, Agents e dismissione Micro sostituiscono i rispettivi installer Bash con componenti Lua e test di comportamento. La migrazione complessiva resta incompleta.

Il tentativo hardware GRUB non è riuscito a sostituire l’avvio Limine. Il nuovo candidato è autonomo, con ricerca ESP per UUID e moduli incorporati; conserva Limine e richiede un nuovo avvio reale prima di promuovere il predefinito. Plymouth testuale è verificato nelle due immagini di avvio correnti; i vecchi snapshot restano intatti.

Lo sprint di consolidamento trasferisce tutti i contenuti attivi nella radice stabile `v2.0/`, senza copie dei vecchi alberi nella root. CI, installer e creazione ISO usano la struttura canonica; gli ingressi Make e agenti restano collegamenti. GitHub conserva i soli file nei percorsi nativi obbligatori. Gli installer dei cloni Bluetooth e alimentazione sono sostituiti da Lua con policy esterna e controlli di comportamento. La migrazione del linguaggio resta incompleta: l’inventario include anche gli ingressi shell che prima erano fuori dagli alberi osservati.

Lo sprint del dispatcher sostituisce gli algoritmi Bash di avvio applicazioni e delega con componenti Lua e policy esterna. Inventario del boot e selezione del candidato GRUB sono ora Lua, con rifiuto delle ambiguità e controllo di BootOrder. Il dispatcher installato è verificato da utente normale; la prova hardware GRUB resta aperta. La documentazione pubblica è organizzata in `docs/it/`, `docs/en/` e `docs/fr/`; istruzioni operative e licenze restano fonti canoniche condivise. I test non autorizzano a dichiarare completata la migrazione di tutti i componenti.

L’analisi di parità Arch è ora un componente Lua in `src/component/platform/`, con inventario in `data/component/platform/`. Legge i pacchetti ufficiali e installati, i riferimenti sorgente e i file posseduti dal runtime senza modificare il sistema. I test coprono assenza del runtime ed errori di inventario: le sedici capacità restano non verificate finché mancano prove indipendenti.

L’orchestrazione dei test e i gruppi dei sottoprogetti passano a Lua, con selezione e ordine dichiarati nei dati. Le suite Lua sono eseguite direttamente, senza wrapper shell; le suite storiche restano conteggiate nell’inventario. Il runner controlla codici di uscita, errori dichiarati e corrispondenza tra asserzioni osservate e riepilogo, compresi gli avvisi.

I test del dispatcher sono riscritti in Lua con fixture tipizzate per XDG, launcher, delega e cataloghi. Sono coperti anche override nascosti, identificatori annidati, modalità privata, preferenze XDG vuote, argomenti letterali, dipendenze mancanti e codici di uscita. La verifica dello scope CLI resta isolata dal sistema reale. I precedenti test Bash del sottoprogetto sono rimossi, senza eseguirne le asserzioni attraverso un interprete nascosto.

Aiuto, elenco lingue, stato della traduzione, selezione del portachiavi e ingressi interattivi del progetto sono ora componenti Lua. I target Make sostituiscono gli script rimossi; l’applicazione resta nella pipeline privilegiata esistente. I test verificano tutte le lingue, backend non supportati, identità root, codici di uscita ed EOF della sessione interattiva senza avviare setup sul sistema reale.

L’installer OSMP è riscritto in Lua e incluso nel registro delle applicazioni. Sorgenti nativi, manifest, metadati e test hanno sedi distinte nelle directory canoniche. Il payload viene validato prima di pubblicare file regolari; collisioni del namespace, collegamenti simbolici nei sorgenti, destinazioni e backup rediretti vengono rifiutati. La skill del widget è registrata nell’inventario comune. Il codice nativo del widget resta identico: la migrazione riguarda installer e struttura.
