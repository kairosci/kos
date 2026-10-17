# Energia

La personalizzazione dell’indicatore di alimentazione elimina l’euristica che segnalava una ricarica lenta, mantenendo visibili gli stati pertinenti come attesa o carica completata sotto il 99%. Non cambia la policy hardware del limite di carica al 75%.

La tastiera illuminata usa il massimo realmente esposto dal dispositivo, con verifica in lettura. I servizi rispettano il ripristino nativo di systemd e lo spegnimento prima dell’ibernazione; non modificano i LED dello schermo o degli indicatori di blocco. Un’interfaccia firmware assente viene segnalata come non supportata, mai come limite applicato.
