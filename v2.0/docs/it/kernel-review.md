# Analisi del kernel

La rilevazione del 16 ottobre 2026 osservava il kernel Omarchy 7.2.5 in esecuzione e il kernel Arch standard 7.2.3 installato. Questi numeri sono una fotografia storica, non un invito a installare versioni vecchie. Il pacchetto ufficiale Arch `linux` è un kernel mantenuto dalla distribuzione, distinto da una compilazione diretta dei sorgenti kernel.org.

Un kernel chiamato «puro» non è automaticamente più sicuro. Contano aggiornamenti, configurazione, moduli, firmware e compatibilità del percorso di avvio. Scegliere il pacchetto ufficiale aggiornato evita una catena di compilazione personale, ma non dimostra da solo la parità con il sistema attuale.

La presenza dei driver i915, iwlwifi e NVMe non prova sospensione, ibernazione, ripresa, audio e recupero. Secure Boot risultava disabilitato. Conservare il kernel funzionante, Limine e le voci di recupero fino a una prova reale del candidato con cifratura, riavvio a freddo e ripristino verificati.

L’inventario Arch contiene sedici capacità da dimostrare indipendentemente: nomi dei pacchetti installati e test legacy verdi non equivalgono a un desktop autonomo. L’analisi è in sola lettura; la rimozione del runtime Omarchy non è ancora implementata. La prova GRUB al prossimo riavvio non autorizza a interrompere la sessione attiva.
