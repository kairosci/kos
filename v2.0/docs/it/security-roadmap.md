# Programma di sicurezza e desktop

La baseline del 13 ottobre 2026 è storica. Il congelamento dello stato live valeva durante quell’audit, non costituisce un divieto attuale: le modifiche autorizzate passano da `make setup`. Nessun sistema è immune per definizione; ogni sprint richiede confini di fiducia, criteri misurabili e recupero verificabile.

La rilevazione comprendeva 137 controlli superati con sei gruppi privilegiati saltati e 85 controlli di compatibilità con un avviso Polkit. UFW, auditd, fail2ban, USBGuard, AppArmor, NetworkManager e Polkit erano attivi; SSH inattivo. Secure Boot era disabilitato, la radice Btrfs cifrata. Hyprland non riportava errori, con `misc:size_limits_tiled=false`; venti file desktop, inventario dei pacchetti e sette stati di servizio erano invariati. I test dei confini degli hook passavano 19 controlli e l’idempotenza 18; la prova grafica interattiva restava pendente.

L’impronta desktop era `cbe3b671ea633afe222d92bc07ae80ac1afb43f3db96c58c2fe362f463288831`, quella pacchetti `33c1ded113f9ab107ae15222a0f7a0ec066d7994683596fa365867e8e42fc2fc`. I manifest temporanei sotto `/tmp/os-baseline.8uINio` non sono recupero durevole. Le PR 65 e 66 abilitarono automazione gratuita e Semgrep 1.180.0 senza installare software sulla macchina.

Il percorso sicurezza copre preservazione baseline, identità di sorgenti e installato, confini root/utente/rete/AUR/plugin, iniezioni, ambiente privilegiato, segreti nei log, symlink, supply chain, porte e firewall, AppArmor, PAM, isolamento servizi, boot cifrato, vulnerabilità delle dipendenze, rilevamento della deriva e prove avversarie con rollback. Ogni fase deve dimostrare il proprio risultato; i test legacy verdi non sostituiscono prove mancanti.

Il percorso desktop copre geometria reale, prototipo offline, propagazione della palette, sidebar Nautilus, dialoghi file, menu contestuali, stati dei checkbox, limiti delle finestre, scaling e monitor multipli, contrasto e focus, workflow LazyVim e rilascio con recupero. Un prototipo HTML non dimostra la modifica dei menu del toolkit nativo; il mouse nell’editor non crea una GUI delle impostazioni.

La consegna richiede ramo dedicato, revisione, test pertinenti e confronto con la baseline dopo l’applicazione autorizzata. Conservare tiling automatico, unico locker, audio, rete, autenticazione, Secret Service, swap e ibernazione. Le scansioni GitHub coprono revisioni pubblicate, non certificano continuamente il sistema installato.
