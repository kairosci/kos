# Architettura Lua

`src/main.lua` prepara il caricamento dei componenti e inoltra gli argomenti al runtime. `src/component/runtime/application.lua` compone i servizi necessari; i componenti di dominio non dipendono dagli ingressi shell. Gli oggetti con stato usano metatable e costruttori espliciti. Le utility pure restano funzioni.

`src/core/` contiene JSON, file, INI, percorsi XDG, processi nativi, cataloghi e pubblicazione atomica. `src/component/boot/` verifica immagini EFI e genera il menu. `src/component/application/` applica preferenze native e configurazioni INI preservando i dati personali.

`data/core/` definisce comandi, dipendenze, lingua, percorsi e composizione del runtime. `data/component/` contiene policy e risorse dei singoli domini. `data/catalog/` contiene le sei lingue. I dati non vengono caricati con `load`, `loadfile` o `dofile` e non vengono interpretati come comandi shell.

La lettura binaria accetta qualsiasi tipo di file. JSON e INI hanno parser dedicati; cataloghi e preferenze usano proprietà e TSV. Configurazioni native YAML, shell o testuali possono essere conservate come risorse senza eseguirle: il loro formato non autorizza a valutarle come codice. Nuovi formati da modificare strutturalmente richiedono un parser con test, non sostituzioni arbitrarie o esecuzione del contenuto.

`script/os-lua` è l'ingresso minimo del runtime. Legge i parametri di bootstrap da dati, calcola la radice dalla propria posizione e avvia Lua con l'ambiente di startup disabilitato. L'applicazione al sistema passa sempre da `make setup`.

La presenza dei vecchi componenti sotto `modules/` e `scripts/` indica lavoro ancora aperto. L'archivio `v1.0` non è un backend del nuovo runtime e non viene eseguito. La roadmap separa implementazione, applicazione live e collaudo hardware.
