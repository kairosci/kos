# Sessione grafica

L’adattatore mantiene in sola lettura i sorgenti del runtime nativo e genera il livello OS da policy esterne. La configurazione Hyprland dell’utente conserva monitor, input, temi e gestione dell’inattività. Lo stato gestito è JSON, non codice Lua eseguibile.

Il menu usa le dimensioni disponibili del monitor e il limite di larghezza previsto dalla policy. Il modello delle applicazioni deve risultare popolato da file desktop reali. I messaggi di runtime sono tradotti in sei lingue. Impostazioni è una sola app per rete, Bluetooth, audio e preferenze del desktop; HyprMod resta disponibile per i controlli avanzati del compositore.

`make setup SCOPE=session` valida Lua e QML prima dell’applicazione e controlla gli errori della sessione dopo la pubblicazione. L’hook di aggiornamento ricostruisce gli adattatori a partire dai sorgenti attualmente installati.
