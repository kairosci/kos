# EasyEffects

Il preset OS Subwoofer aggiunge armoniche alle basse frequenze senza pretendere di modificare le capacità fisiche degli altoparlanti. Prevede margine in ingresso, un filtro passa-alto a 60 Hz, elaborazione armonica sotto 110 Hz e un limitatore con soglia di −2 dB. Non garantisce l’assenza di distorsioni a ogni volume o su ogni dispositivo.

Il componente Lua installa il preset `OS-Subwoofer` e l’avvio automatico nativo con `make setup SCOPE=easyeffects` (o `make easyeffects`). Lo attiva solo in una sessione utente disponibile e verifica il preset caricato. Le esecuzioni successive conservano un preset diverso scelto esplicitamente. I database EasyEffects originali vengono salvati in modo privato nello stato OS prima della prima applicazione; i preset esistenti restano disponibili.

L’installazione conserva lo stato di mute, il dispositivo audio e gli effetti del microfono. Le copie dei dati personali hanno permessi privati. Le impostazioni del preset appartengono ai dati del componente; la verifica deve usare la versione nativa supportata, inclusa la compatibilità con EasyEffects 8.2.9.
