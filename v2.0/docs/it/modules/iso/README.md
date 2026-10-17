# Immagine ISO

Il componente ricostruisce l’ultima immagine stabile della base supportata aggiungendo l’intero repository tracciato in `/opt/os` e l’icona KMono ciano in `/usr/share/pixmaps/os.png`. Il checksum upstream viene verificato prima della modifica; la firma upstream non copre l’immagine ricostruita. Le release pubblicate sono immutabili: correzioni e nuovi asset richiedono una nuova versione.

Le release contengono l’ISO suddivisa in parti, il file `os-vX.Y.iso.sha256` e gli helper `download-release.sh` e `download-release.ps1`. L’helper Bash richiede curl, jq e sha256sum; quello PowerShell supporta Windows PowerShell 5.1 e PowerShell 7. Entrambi scaricano, ricompongono e verificano SHA-256 prima di pubblicare l’immagine nella directory corrente, rifiutando file di destinazione già esistenti. È possibile scegliere un tag esplicito; altrimenti viene usata l’ultima release.

I temporanei sono privati nella directory di destinazione, non nella RAM di `/tmp`. Le parti vengono aggiunte all’immagine e rimosse una alla volta: occorre spazio per l’ISO intera più una parte. Per scegliere la destinazione cambiare directory prima di eseguire l’helper. È preferibile scaricare e leggere lo script prima dell’esecuzione.

La CI estrae `/opt/os` dall’immagine finita e confronta ogni file con il repository materializzato al commit firmato del tag. Una differenza blocca la pubblicazione. Questa verifica non avvia né installa l’ISO; gli helper di download verificano il checksum, non il contenuto del repository.

L’overlay non ricostruisce la radice live compressa e non fa copiare automaticamente la configurazione dall’installer. Dopo l’installazione copiare `opt/os` dal supporto su storage persistente ed eseguire lì `make setup`. La base del desktop attualmente supportata rimane necessaria.

`make iso` costruisce localmente l’immagine con l’overlay del componente; cache e download upstream risiedono nella cache XDG dell’utente. La pubblicazione richiede un nuovo tag firmato `vX.Y` da un commit revisionato e mergiato. Se il workflow fallisce prima della pubblicazione, si può rilanciare ISO con lo stesso tag; una release già pubblicata non viene sostituita.

GRUB è un candidato separato, non ancora confermato come percorso di avvio effettivo su questa macchina. La policy mantiene Limine fino alla prova reale. Il percorso supportato richiede UEFI e una ESP individuabile senza ambiguità, conserva cifratura e parametri delle snapshot e include il recupero Snapper. Misurazioni TPM non equivalgono a Secure Boot firmato né alla verifica hash specifica di Limine.
