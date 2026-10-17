# Transizione di avvio EFI

[Italiano](boot-transition.md) · [English](../en/boot-transition.md) · [Français](../fr/boot-transition.md)

Il sistema osservato si avvia da Limine, voce firmware 0001. L’ESP FAT è montata su `/boot`; la radice Btrfs cifrata usa parametri specifici per radice, resume e AppArmor. Le osservazioni riguardano questa macchina e non garantiscono il comportamento di altro hardware.

`make setup SCOPE=boot-assessment` registra mount, firmware, dispositivi, configurazioni, preset e immagini sotto `/var/lib/os/boot-assessment`, privato di root. Lua valida immagini PE e digest BLAKE2b e rifiuta immagini mancanti, percorsi fuori dall’ESP, campi duplicati, protocolli incompatibili e integrità alterata. Gli argomenti dei singoli snapshot restano separati. L’inventario non cambia le preferenze del firmware.

`make setup SCOPE=grub-trial` prepara un candidato separato con `--no-nvram`. La registrazione usa `--create-only`; BootOrder resta invariato e Limine è conservato. Il menu usa le stesse immagini EFI verificate e i loro parametri di cifratura, resume e sicurezza. Policy e parser appartengono a `data/component/boot/` e `src/component/boot/`; `grub-script-check` valida prima della pubblicazione. L’inventario Limine resta una dipendenza transitoria.

Il primo tentativo hardware è tornato a Limine. Secure Boot era disabilitato e il vecchio candidato aveva un prefisso disco implicito. `SCOPE=grub-repair` ricostruisce soltanto il candidato autonomo con moduli incorporati e ricerca ESP per UUID. Questo elimina la dipendenza dai moduli esterni, ma non dimostra la causa del fallimento o il successo dell’avvio.

Dopo la scelta dell’utente, `SCOPE=boot-trial-select` valida inventario e menu, identifica un candidato unico per etichetta e percorso EFI e imposta solo BootNext, verificando BootOrder invariato. Non riavvia la sessione. Prima di cambiare il predefinito occorre verificare avvio, sblocco cifrato, radice persistente, grafica, rete, audio, sospensione, resume e recupero. Kernel corrente, Limine e immagine EFI di riserva restano disponibili.

`SCOPE=boot-appearance` sceglie Plymouth testuale e rigenera le UKI correnti attraverso gli strumenti nativi. Prima verifica una copia persistente completa dell’ESP; poi conserva tutte le coppie immagine/argomenti, anche quando più snapshot condividono un’immagine. Controlla PE, digest e presenza del tema testuale senza grafica Omarchy negli initrd correnti. Un errore ripristina ESP e configurazione precedenti; gli snapshot storici restano intatti.

Un controllo successivo ha rilevato digest vecchi nel menu nativo dopo una rigenerazione riuscita. La riconciliazione accetta soltanto immagini coincidenti con il manifest privato già verificato e con le stesse coppie immagine/argomenti. Valida l’intero menu prima della pubblicazione atomica e rifiuta variazioni sconosciute. Il processo esterno che ha riscritto quei digest non è stato identificato.

Riferimenti: [chainloader GRUB](https://www.gnu.org/software/grub/manual/grub/html_node/chainloader.html), [configurazione Limine](https://github.com/limine-bootloader/limine/blob/v12.x/CONFIG.md). Validazione sintattica e integrità non sostituiscono una prova di avvio e sblocco reali.
