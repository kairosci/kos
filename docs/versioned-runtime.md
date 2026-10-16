# Runtime Lua versionato

`v2.0/` contiene la versione Lua in sviluppo: `src/core/` per gli algoritmi condivisi, `src/component/` per i domini, `data/` per policy e cataloghi, `script/` per gli starter essenziali e `tests/lua/` per i test dei componenti. `v1.0/` resta il backup Bash immutabile.

Gli ingressi `src`, `data`, `script` e `tests/lua` nella radice sono collegamenti alla sola copia canonica. Servono ai chiamanti di provisioning ancora attivi; non contengono implementazioni duplicate. `make setup` resta il solo percorso di applicazione. I bundle installati sono autonomi e mantengono le directory interne `src`, `data` e `script`.

Eseguire `v2.0/script/os-lua migration-report` per l'inventario dell'intero repository e `v2.0/script/os-lua verify-full-lua` per il criterio rigoroso di completamento. Un codice di uscita non nullo segnala una migrazione incompleta. Lo stato di ogni sprint e della parità funzionale è mantenuto soltanto in [roadmap](roadmap.md). I test dei componenti migrati verificano il comportamento sostituito; i test Bash ancora verdi non attestano una sostituzione Lua.
