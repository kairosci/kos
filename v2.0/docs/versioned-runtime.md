# Struttura versionata

`v1.0/` conserva l’archivio Bash originale e il relativo checksum immutabile. Non è una sorgente eseguibile. `v2.0/` è l’unica radice attiva del progetto e resta tale per le release successive: una release non crea un nuovo albero di sorgenti.

Codice Lua in `src/core/` e `src/component/`, dati in `data/`, starter in `script/`, test in `tests/`, documentazione in `docs/`. Il provisioning Bash non ancora sostituito è sotto `scripts/`, `hooks/` e `modules/` della stessa radice attiva. Spostarlo non ne certifica la migrazione Lua.

La radice del repository conserva soltanto i metadati richiesti da Git e GitHub e i collegamenti di ingresso per Make, documentazione e agenti. GitHub richiede i workflow reali sotto `.github/workflows/` e Dependabot sotto `.github/`; tali file non possono essere sostituiti da collegamenti. Le policy del repository vivono in `v2.0/data/repository/`. I vecchi ingressi `src`, `data`, `script`, `scripts`, `tests`, `modules`, `hooks`, `conf` e `docs` non sono ricreati nella radice.

`make test` e `make setup` funzionano dalla radice e da `v2.0/`; `make setup` resta il solo percorso di applicazione. Gli strumenti richiamati direttamente usano il prefisso `v2.0/`. I bundle installati mantengono le directory interne `src`, `data` e `script`.

`v2.0/script/os-lua migration-report` ispeziona l’intero repository, inclusi file nuovi e starter senza estensione. `v2.0/script/os-lua verify-full-lua` continua a fallire finché rimangono algoritmi shell o componenti legacy. Lo stato effettivo della migrazione è mantenuto nella [roadmap](roadmap.md).
