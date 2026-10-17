# Registro storico dell’audit

Questo documento riassume osservazioni del 12–15 ottobre 2026, non lo stato corrente né una certificazione. La rilevazione storica registrava 29 suite, 1457 asserzioni e 166 controlli. Lynis riportava indice 80 e 22 suggerimenti; Semgrep incontrava sei problemi di parsing nella versione allora usata. Quattro profili AppArmor risultavano in enforcement. Venti anteprime native avevano geometria 1800×1012.

arch-audit presentava 23 record, di cui tre classificati alti. Le versioni installate richiedevano confronto con gli intervalli affetti: PAM 1.7.2 rispetto alla correzione 1.7.1 per CVE-2025-6020; DjVu 3.5.30.1 rispetto a 3.5.29 per CVE-2025-53367; libxml2 2.15.4 fuori dagli intervalli indicati per CVE-2025-6170, CVE-2025-49795, CVE-2025-49794 e CVE-2025-49796. Gli altri venti record non erano ancora stati esaminati: il rapporto non era una dichiarazione di assenza di vulnerabilità.

Il 15 ottobre una scansione ClamAV limitata a dieci minuti fu interrotta, con avvisi per oggetti non supportati. Non equivale a una scansione completa pulita. Polkit non era disponibile per alcune verifiche in quella sessione; questa limitazione storica non vieta le applicazioni successive autorizzate attraverso la pipeline.

I percorsi temporanei citati nell’audit originale non sono backup durevoli. Per valutare il sistema attuale occorrono nuovi controlli, inventario dei pacchetti effettivo e prove native, mantenendo separate la sicurezza del repository e quella dell’installazione.
