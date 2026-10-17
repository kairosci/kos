# OS

[Italiano](README.md) · [English](../../en/root/README.md) · [Français](../../fr/root/README.md)

OS configura un desktop Arch Linux esistente tramite provisioning posseduto dal repository. L’installazione attiva richiede ancora Omarchy. L’indipendenza del runtime è l’obiettivo, non un risultato già raggiunto: pacchetti installati e vecchi test verdi non dimostrano la parità delle sostituzioni.

`v2.0/` è l’unica struttura attiva per versioni presenti e future; `v1.0/` conserva l’archivio originale immutabile. Gli algoritmi vivono in `src/core/` e `src/component/`, policy e risorse in `data/`, starter essenziali in `script/`, test in `tests/` e documentazione nelle directory linguistiche. Gli algoritmi Bash residui restano visibili nell’inventario. QML, CSS, desktop entry e unità systemd mantengono i formati nativi della piattaforma.

## Installazione e uso

Lavorare dalla radice o da `v2.0/`. `make setup` richiede autenticazione Polkit locale ed esegue la pipeline privilegiata. Prima si modificano i file del repository; le correzioni non vengono copiate direttamente nel sistema o nella sessione. Il setup completo riconcilia pacchetti, applicazioni, temi, autenticazione, firewall, sicurezza, hardware e desktop. Operazioni distruttive o di recupero richiedono selezione esplicita.

| Comando | Funzione |
| --- | --- |
| `make help` | Riferimento localizzato |
| `make test` | Suite automatiche del repository |
| `make verify` | Verifiche in lettura del sistema applicato |
| `make setup SCOPE=cli` | Dispatcher Lua e ruoli applicativi |
| `make setup SCOPE=lua-applications` | Configurazioni applicative migrate |
| `make setup SCOPE=settings` | Impostazioni unificate e integrazione HyprMod |
| `make setup SCOPE=session` | Validazione e pubblicazione della sessione |
| `make setup SCOPE=wallpaper` | Sfondo unico con logo e palette |
| `make setup SCOPE=performance` | Reattività e budget dell’editor |
| `make setup SCOPE=keyboard` | Retroilluminazione della tastiera |
| `make setup SCOPE=boot-assessment` | Inventario e verifica dell’avvio |

`RUN_MIGRATIONS=1` esegue le vere migrazioni native prima del debloat, senza inventare marcatori. `RESTORE_OMARCHY=1` salva le configurazioni prima del ripristino. `RESET_SNAPSHOTS=1` crea e verifica una baseline prima di ritirare snapshot precedenti; conserva zero, attivo e predefinito. Il provisioning ordinario rifiuta radici temporanee da snapshot. Il recupero conserva copie nella home persistente.

## Desktop e applicazioni

Super e virgola apre Impostazioni, con desktop, rete, Bluetooth, audio e alimentazione. Le modifiche del compositore vengono validate, serializzate e salvate automaticamente. NetworkManager, BlueZ e PipeWire mantengono servizi e profili. IP avanzato, VPN, autenticazione enterprise e gestione PIN Bluetooth integrata restano incompleti; vedere [Impostazioni](../settings.md).

Brave Origin è il browser, Zed l’editor grafico, LazyVim pacchettizzato l’editor terminale e Nautilus il file manager con GVFS e File Roller. OnlyOffice gestisce documenti d’ufficio, Papers PDF, Loupe immagini, Celluloid media, Baobab spazio disco e Resources risorse del sistema. GTK fornisce dialoghi file; Hyprland screenshot e condivisione schermo. Le librerie GTK richieste non installano un desktop GNOME. GNOME Keyring fornisce Secret Service con Seahorse; dati e configurazioni personali ritirati sono conservati.

`os app` risolve desktop entry e trasmette argomenti letterali a UWSM. `os app --resolve settings` restituisce JSON senza avviare finestre. La navigazione privata richiede l’azione dichiarata del browser. Dispatcher e installazione sono componenti Lua; lo starter individua soltanto il runtime. Gli altri gruppi mantengono il contratto nativo. Vedere la [guida del comando](../modules/os/README.md).

Ogni tema espone un solo sfondo con logo e palette. Varianti precedenti e sfondi personali aggiuntivi vengono archiviati fuori dal selettore, conservando originali pacchettizzati e dati personali. GTK, icone e Zed seguono la palette attiva. Le anteprime catturano l’intero monitor reale con finestre campione isolate e ripristinano tema, workspace, sfondo e notifiche su ogni percorso d’uscita. L’applicazione passa da setup, con `REBUILD_PREVIEWS=1` quando richiesto.

## Sicurezza e risorse

Setup possiede sysctl, controlli PAM, UFW, isolamento SSH, AppArmor, auditd, fail2ban, USBGuard e scansioni programmate. D-Bus, Polkit, NetworkManager, display manager, audio e il singolo locker devono restare funzionanti. L’audit registra rilevamenti da esaminare: non elimina automaticamente file e non certifica l’assenza di malware o vulnerabilità. Vedere la [politica di sicurezza](SECURITY.md).

La reattività monitora le slice delle applicazioni e del background, conserva swap e ibernazione e protegge la sessione senza riavviare desktop o audio. I budget adattivi riducono la concorrenza quando le risorse sono limitate. Un intervento OOM può chiudere un intero scope applicativo e perdere lavoro non salvato; nessuna policy garantisce assenza di esaurimenti o blocchi per carichi arbitrari. Vedere [prestazioni](../performance.md).

Carica della batteria e retroilluminazione vengono rilevate per capacità e verificate rileggendo l’hardware. Il firmware non supportato è segnalato senza inventare un limite applicato. Sospensione e ripresa conservano locker e ordine nativo di spegnimento della tastiera.

## Avvio e indipendenza Arch

L’inventario verifica integrità EFI e conserva cifratura, radici degli snapshot, sicurezza e resume. GRUB resta un candidato di prova separato; il primo tentativo hardware è tornato a Limine. Il candidato autonomo cerca l’ESP per UUID, mantenendo ordine permanente e recupero. Plymouth testuale è verificato nelle immagini correnti. Avvio, sblocco, sospensione e recupero richiedono prove hardware reali; non viene effettuato un riavvio automatico. Vedere [transizione di avvio](../boot-transition.md) e [migrazione Arch](../arch-migration.md).

## Sviluppo e release

Le modifiche partono da feature branch ed entrano in `main` tramite PR firmate, verificate e unite con squash. CI e sicurezza devono riferirsi alla base corrente, senza bypass. Titoli Conventional Commits e descrizioni vuote rispettano la policy. Tag, metadati e asset pubblicati sono immutabili; una correzione richiede una versione nuova.

La [guida ISO](../modules/iso/README.md) descrive download, checksum e limiti. La CI confronta tutta la configurazione inclusa con il sorgente firmato prima della pubblicazione; non avvia l’immagine e non dimostra che l’installazione copi OS nella radice installata.

`v2.0/script/os-lua migration-report` osserva l’intero repository. `verify-full-lua` fallisce finché restano algoritmi Bash o Ruby e componenti legacy da sostituire o ritirare legittimamente. [Architettura](../lua-architecture.md), [indice](../README.md), [contributi](CONTRIBUTING.md) e [roadmap](../roadmap.md) documentano responsabilità e avanzamento effettivo.
