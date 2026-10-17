# Prestazioni del sottoprogetto storico

Il sottoprogetto conserva la precedente automazione Bash delle prestazioni. La configurazione corrente del desktop è descritta nella guida delle prestazioni e applicata con `make setup SCOPE=performance`. Le policy correnti del progetto prevalgono sui vecchi script autonomi.

Le impostazioni storiche comprendono limite di carica al 75% con persistenza, UPower con soglie 20/10/5 e ibernazione critica, manutenzione TRIM e regolazioni del kernel. La precedente disabilitazione del watchdog NMI non descrive la policy corrente e non va reintrodotta implicitamente durante la migrazione.

La verifica deve distinguere interfacce hardware supportate, valori realmente riletti e impostazioni soltanto dichiarate. Swap, ibernazione, audio e sessione devono restare funzionanti. Nessuna ottimizzazione può garantire assenza assoluta di OOM, latenza o blocchi su ogni carico.
