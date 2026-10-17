# Neovim e LazyVim

L’editor del terminale usa Neovim e il LazyVim dei pacchetti. La procedura inizializza solo configurazioni mancanti e verifica i plugin presenti nella cache; una configurazione esistente non riconosciuta richiede gestione esplicita, senza sovrascrittura silenziosa. L’input del mouse rimane disponibile.

F1 mostra l’aiuto, Ctrl+S salva, Ctrl+Q richiede conferma quando necessario, Ctrl+P apre i file, Ctrl+F cerca, F2 apre l’esploratore e F3 cerca nel progetto. F4 o `:Settings` aprono la configurazione; Spazio mostra i comandi disponibili. Questi controlli non trasformano l’editor in un’app grafica per le impostazioni di sistema.

La configurazione resta Lua. Configurazioni locali dei progetti e modeline eseguibili vengono disabilitate. Aggiornare plugin o scaricare strumenti di linguaggio introduce codice eseguibile nella sessione dell’utente e richiede la stessa attenzione riservata alle altre dipendenze.
