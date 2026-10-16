# Migrazione strutturale a Ruby e Lua

L'obiettivo è Arch indipendente da Omarchy con funzioni equivalenti. Il runtime attuale dipende ancora da Omarchy. Questa roadmap distingue implementazione, applicazione e verifica hardware; nessun esito viene dedotto dalla sola presenza di un pacchetto.

| Sprint | Ambito e dipendenze | Criterio di completamento | Stato |
| --- | --- | --- | --- |
| Conservazione | Archivio della versione Bash precedente | Archivio verificabile, commit di origine, nessuna esecuzione automatica | Archivio creato in `v1.0` |
| Sessione stabile | Pubblicazione atomica e strumenti desktop | Test di scrittura concorrente, Lua e QML validi, nessun errore live, menu popolato | Applicato e verificato nella sessione attiva |
| Interfacce coerenti | GTK e HyprMod, dipende dalla sessione stabile | Layout compatto adattivo, icone simboliche, preferenze personali conservate | Implementato e applicato |
| Dominio di avvio | Parser Ruby, policy JSON e menu GRUB | Integrità EFI, argomenti cifratura e resume conservati, test negativi e sintassi | Implementato e applicato come candidato |
| Avvio hardware | Dipende dal dominio di avvio | Avvio GRUB reale, sblocco, sessione, rete, audio, sospensione e recupero | Da eseguire |
| Cataloghi Ruby | Sei lingue, stessa policy di precedenza e errori di avvio localizzati | Test delle sei lingue, selezione della lingua e chiave mancante | Implementato e applicato |
| Fondazioni Ruby | Cataloghi, percorsi XDG, processo e pubblicazione file | Classi con responsabilità reali, errori localizzati, test isolati e contratto installato | Da implementare |
| Moduli Ruby | Provisioning, pacchetti, sicurezza, temi, verifica | Ogni modulo sostituisce tutti i suoi chiamanti e supera prove di equivalenza e idempotenza | Da implementare dopo le fondazioni |
| Runtime Lua | Configurazione, input, monitor, menu e tema indipendenti | Sessione di prova senza sorgenti Omarchy, parità misurata dell'inventario Arch | Da implementare |
| Consolidamento | Dipende da tutte le verifiche precedenti | Rimozione dipendenze Omarchy e Bash attivo, CI Ruby/Lua completa, avvio a freddo e recupero provati | Da eseguire |

## Proprietà dei moduli

`modules/platform/arch/` possiede inventario e dominio di avvio; `modules/conf/session/` possiede adattatore Lua, menu e verifica della sessione; `modules/conf/hyprmod/` possiede impostazioni grafiche e loro policy; `modules/conf/gtk/` e gli hook di tema possiedono la palette. I moduli mantengono dati in `data/`, algoritmi in `scripts/`, interfacce native nelle rispettive directory e test presso il modulo quando indipendenti.

La pubblicazione resta esclusivamente nella pipeline privilegiata. La migrazione Ruby dovrà sostituirne le responsabilità mantenendo lo stesso ingresso, senza duplicare due implementazioni attive. Il backup `v1.0` non partecipa a installazione, CI o discovery dei moduli.

## Evidenze richieste

Per ciascuno sprint registrare comandi, risultati e limiti verificati nel relativo PR. Le sei lingue condividono chiavi e argomenti. Valori di policy restano dichiarati nei dati; percorsi e capacità vengono rilevati. Configurazioni mancanti o invalide interrompono l'operazione prima della pubblicazione. Un riavvio non ancora eseguito resta una verifica aperta.
