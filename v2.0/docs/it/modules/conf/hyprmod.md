# Impostazioni avanzate di Hyprland

HyprMod offre controlli GTK4 e libadwaita per configurazione del compositore, monitor, tastiera, mouse, scorciatoie, regole e workspace. Anteprima, modifiche pendenti, salvataggio e annullamento evitano l’editing manuale. La configurazione generata `~/.config/hypr/hyprland-gui.lua` viene caricata dopo i valori gestiti e conservata da setup. L’app Impostazioni, aperta anche con Super+virgola, riunisce rete, Bluetooth e audio; HyprMod resta il controllo avanzato del compositore.

La sorgente HyprMod 0.5.0 è fissata alla revisione `e148d221cc62edaa8d1b8ffac0f0a57edcb8e3c1`. Sorgenti e wheel Python pure hanno hash SHA-256 nel lock. GTK, libadwaita, Cairo, PyGObject, backend di build e uv provengono da pacman. Python è il runtime dell’applicazione, non un sostituto dell’implementazione Lua di OS. Nessuno script remoto viene eseguito e nessun ambiente pip globale viene alterato. L’ambiente viene ricreato quando cambiano lock o Python di sistema.

`make setup SCOPE=settings` installa e valida la configurazione predisposta prima della pubblicazione. Patch esatta, dimensioni JSON, CSS e icone simboliche seguono la palette. Le preferenze esplicite di salvataggio automatico restano autorevoli. L’uso della GUI autorizza le sue scritture, non modifiche dirette degli agenti fuori dalla pipeline.

Riferimento: [sorgente fissata](https://github.com/BlueManCZ/hyprmod/tree/e148d221cc62edaa8d1b8ffac0f0a57edcb8e3c1).
