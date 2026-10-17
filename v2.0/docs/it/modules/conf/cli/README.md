# Helper e temi del terminale

`make cli` applica il componente Lua tramite `make setup SCOPE=terminal`.

`src/component/terminal/` gestisce gli helper, la palette e l’installazione. Le guide dei comandi sono disponibili in sei lingue in `data/component/terminal/help/`. Policy, integrazione shell e modelli sono dati separati. L’adattatore Bash espone soltanto `helper` alla shell interattiva; l’hook del tema avvia soltanto Lua.

L’installer conserva contenuto e permessi della shell, pubblica un solo blocco gestito e archivia privatamente il vecchio helper. FZF usa i colori validati del tema reale. LazyGit usa i livelli nativi di `LG_CONFIG_FILE`: la configurazione personale resta intatta e la palette generata viene aggiunta una sola volta. Gli elenchi espliciti vengono conservati. Palette non valide, backup reindirizzati e blocchi incompleti interrompono il flusso prima di sostituire l’integrazione della shell.

Eseguire `lua -E tests/lua/run.lua "$PWD" terminal` da `v2.0/` per i test isolati.
