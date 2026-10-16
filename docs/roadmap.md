# Migrazione integrale a Lua

Il linguaggio obiettivo è esclusivamente Lua. Ruby viene ritirato. La struttura definitiva separa algoritmi in `src/`, componenti in `src/component/`, dati in `data/` e ingressi essenziali in `script/`. Le applicazioni native mantengono i formati di interfaccia richiesti dalla piattaforma.

| Sprint | Risultato richiesto | Stato |
| --- | --- | --- |
| Conservazione | Backup Bash verificabile in `v1.0`, escluso da installazione e discovery | Completato |
| Fondazioni Lua | Processi, JSON, lettura file, cataloghi e pubblicazione atomica senza Ruby | Applicato e verificato con test automatici e controllo live |
| Avvio Lua | Parser EFI, BLAKE2b, parametri cifratura e resume, generazione e pubblicazione GRUB | Applicato come candidato; collaudo hardware al prossimo riavvio |
| Componenti desktop | Riscrittura dei produttori di configurazione e degli hook in `src/component/`, dati centralizzati | Dieci applicazioni e componente sfondi con rendering e installer migrati; altri produttori da sostituire |
| Provisioning Lua | Pacchetti, sicurezza, alimentazione, manutenzione e verifica tramite componenti Lua | Da implementare |
| Consolidamento struttura | Eliminazione di `modules/` e degli algoritmi Bash attivi, soli ingressi necessari in `script/` | Da completare dopo le sostituzioni |
| Parità Arch | Runtime indipendente, prova avvio, sospensione, recupero e inventario delle funzioni | Verifica hardware aperta |

I primi componenti vengono sostituiti insieme ai loro chiamanti installati. I cataloghi canonici si trovano in `data/catalog/`; comandi nativi, selezione lingua e layout del runtime sono policy in `data/core/`; struttura del menu e policy di avvio sono in `data/component/boot/`. Configurazioni non valide interrompono il flusso prima della pubblicazione. Nessun dato viene eseguito come codice.

La pipeline `make setup` resta l'unico percorso di applicazione al sistema. La migrazione è completa soltanto quando non rimangono algoritmi Bash o Ruby attivi: spostare i vecchi file o chiamarli da Lua non soddisfa il requisito. Il collaudo del prossimo avvio resta distinto dai test automatici.

Il catalogo sfondi espone una sola immagine con il logo e la palette del tema. La policy vive in `data/component/wallpaper/`; il componente Lua archivia le varianti precedenti e gli sfondi personali aggiuntivi fuori dal selettore nativo. Rendering, geometria, cache e installazione del runtime sfondi sono implementati in Lua; gli ingressi shell residui inoltrano soltanto al runtime.

Il criterio di completamento è eseguibile: `script/os-lua migration-report` elenca algoritmi shell residui e file nella struttura legacy; `script/os-lua verify-full-lua` fallisce finché rimangono. I quattro starter ammessi sono verificati per contenuto tramite digest BLAKE2b. Il report include anche file nuovi e script senza estensione; non usa una percentuale dedotta dal numero di file.
