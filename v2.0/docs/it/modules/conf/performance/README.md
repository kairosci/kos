# Reattività del desktop

La policy controlla soltanto gli slice delle applicazioni e dei processi in background. La pressione di memoria prolungata è valutata al 40% per dieci secondi e l’uso dello swap all’80%. I pesi CPU favoriscono la sessione con 200 rispetto a 25 per il background; `MemoryLow` protegge 512 MiB negli antenati previsti.

Non estendere mai la selezione OOM all’intera sessione. Swap e ibernazione esistenti vanno conservati; l’applicazione della policy ricarica i gestori utente senza riavviare desktop o audio. Un intervento OOM può comunque terminare un gruppo applicativo e perdere lavoro non salvato: questi limiti non garantiscono memoria infinita.

I template sotto `modules/conf/performance/data/` sono l’autorità dei valori. `make setup SCOPE=performance` riconcilia la policy; i controlli di configurazione e runtime sono distinti dai test con fixture.
