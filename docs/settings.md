# Impostazioni

L’applicazione `os app settings`, richiamata anche con Super e virgola, riunisce desktop Hyprland, rete, Bluetooth e audio nella stessa finestra tiling. Il menu espone un solo ingresso Impostazioni. I ruoli storici `os app network`, `os app bluetooth` e `os app audio` aprono la stessa applicazione.

La sezione desktop legge i valori correnti del compositore. Offre bordi, arrotondamento, sensibilità del puntatore, ripetizione dei tasti, animazioni, sfocatura, ombre, scorrimento naturale, tocco per clic e layout tastiera. Le modifiche vengono validate su una copia della configurazione prima di pubblicare il solo modulo gestito `hypr/os-settings.lua`. Lo stato è JSON privato; gli altri file personali restano preservati. Una ricarica fallita ripristina il modulo precedente. Gli ingressi GUI sono serializzati con un lock e hanno errori visibili. Questa selezione non copre ancora tutti i controlli avanzati di HyprMod, che rimane installato.

La pagina rete usa direttamente NetworkManager attraverso Quickshell: dispositivi Ethernet e Wi-Fi, connessione, disconnessione, rimozione dei profili e password WPA personali. Le password passano direttamente al servizio tramite l’API nativa, mai attraverso argomenti di processo o cataloghi. VPN, parametri IP manuali e autenticazione enterprise non sono ancora editabili da questa finestra; i profili esistenti rimangono conservati.

La pagina Bluetooth usa BlueZ per alimentazione, ricerca, associazione, connessione e attendibilità. Eventuali richieste di PIN richiedono l’agente Bluetooth già presente; questa applicazione non implementa ancora un agente di autenticazione proprio. La ricerca avviata dalla pagina viene arrestata quando si lascia la sezione. Audio usa PipeWire e WirePlumber per dispositivi di ingresso e uscita, volume, silenziamento e dispositivo preferito.

Algoritmi, validazione e installazione sono Lua in `v2.0/src/component/settings/`. L’interfaccia nativa QML vive nello stesso componente; policy, icone simboliche, dimensioni e campi sono in `v2.0/data/component/settings/`. I testi provengono dai sei cataloghi condivisi. La palette deriva dal tema attivo. Il processo termina chiudendo la finestra e non introduce polling o servizi permanenti.

Gli agenti applicano le modifiche tramite `make setup SCOPE=settings`; le scelte effettuate dall’utente nell’app sono salvate dai relativi servizi e dal backend Lua. Verifiche automatiche, connessione Wi-Fi reale, associazione Bluetooth e prove hardware restano evidenze distinte.

Riferimenti: [API NetworkManager di Quickshell](https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/Networking/), [credenziali Wi-Fi](https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/WifiNetwork/).
