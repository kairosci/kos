# Documentazione OS

[Italiano](README.md) · [English](../en/README.md) · [Français](../fr/README.md)

`v2.0/` è la radice attiva per tutte le versioni successive; `v1.0/` conserva l’archivio originale verificabile. Codice, dati, test e documentazione restano separati. La [struttura versionata](versioned-runtime.md) descrive i percorsi e le eccezioni native di GitHub.

Le [Impostazioni](settings.md) riuniscono desktop, rete, Bluetooth, audio e alimentazione in una sola applicazione. La [reattività](performance.md) descrive il budget dei processi e i limiti della protezione OOM. L’[architettura Lua](lua-architecture.md) distingue algoritmi, dati, starter e interfacce native.

La [transizione di avvio](boot-transition.md) conserva cifratura e recupero. La [migrazione Arch](arch-migration.md) richiede parità delle funzioni e prove hardware prima di rimuovere Omarchy. La [roadmap](roadmap.md) distingue implementazione, applicazione e collaudo; un test verde non dimostra la migrazione completa.

Dalla radice del repository o da `v2.0/`, `make test` esegue le suite e `make verify` controlla il sistema corrente. `make setup` è l’unico percorso per applicare modifiche al sistema; gli scope limitano l’intervento al dominio richiesto. Non usare copie manuali o riavvii di servizi per correggere lo stato live.

Le istruzioni normative degli agenti e le skill restano nella loro fonte inglese sotto `docs/en/`, raggiunta tramite collegamenti. Le [istruzioni del progetto](../en/root/AGENTS.md), la [politica di sicurezza](../en/root/SECURITY.md), le [guide dei moduli](../en/modules/conf/README.md) e la [guida ISO](../en/modules/iso/README.md) conservano i dettagli tecnici e storici. La licenza originale non viene tradotta o modificata.
