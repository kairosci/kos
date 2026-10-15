# ISO Omarchy personalizzata

`scripts/customize.sh` scarica l’ultima ISO stabile Omarchy e il checksum pubblicato, verifica l’immagine, applica i file dell’overlay e ricostruisce una ISO avviabile. `xorriso` riproduce le impostazioni di boot riconosciute nell’immagine originale.

Inserisci in `overlay/` i file da aggiungere o sostituire, mantenendo i percorsi relativi alla radice ISO. Per esempio, `overlay/boot/grub/grub.cfg` sostituisce `/boot/grub/grub.cfg` nell’immagine.

Esegui `make iso-customize` per usare l’overlay predefinito. Puoi scegliere un overlay e un percorso di output diversi con:

```bash
bash modules/omarchy-iso/scripts/customize.sh --overlay /percorso/overlay --output /percorso/omarchy-personalizzata.iso
```

Il file ISO originale resta nella cache `${XDG_CACHE_HOME:-$HOME/.cache}/os/omarchy-iso/`. Accanto all’immagine personalizzata viene scritto un checksum SHA-256. La firma upstream non è valida per l’immagine ricostruita. Non inserire nell’overlay credenziali, chiavi private o segreti; l’installazione automatica Omarchy supportata usa un volume separato etichettato `cidata`.
