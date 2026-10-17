# GTK e palette

L’hook GTK applica la palette selezionata a GTK e libadwaita dopo ogni cambio di tema. Materia fornisce la base; l’overlay Qogir usa l’accento esatto del tema. Controlli compatti e piatti mantengono distinguibili selezione, focus e stato disabilitato. Le durate delle animazioni sono dati di policy, non valori inseriti negli algoritmi.

Il componente applicativo Lua pubblica l’adattatore Hyprland, il modello della palette e le icone Nerd Font tramite `make setup SCOPE=gtk` (o `make gtk`), poi applica le impostazioni GTK. Le migrazioni archiviano soltanto l’hook legacy con il comando previsto e ne preservano i file originali.

I dialoghi nativi per file e applicazioni restano funzionanti. L’integrazione non riscrive gli stili privati di ogni applicazione: un’anteprima HTML non prova il comportamento del toolkit installato. Gli asset Nerd Font 3.5.1 conservano provenienza e licenze. Le modifiche si applicano attraverso la pipeline; la scelta esplicita di un tema successivo prevale sul primo avvio scuro.
