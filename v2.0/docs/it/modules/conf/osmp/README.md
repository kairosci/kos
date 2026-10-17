# Installazione di OSMP

L’installer pubblica il plugin locale con identificatore `os.osmp`. Prima dell’attivazione valida un payload autonomo contenente soltanto sorgenti di runtime, manifest e licenza canonica. I collegamenti alla documentazione non devono entrare nel payload; nessuna copia del plugin viene scaricata da repository remoti.

L’integrazione riconcilia il catalogo nativo e archivia la precedente installazione `krosci.omamp`. Manifest e versione del pacchetto devono corrispondere. Il popup ritirato `os.media` resta disabilitato; il menu apre Celluloid come normale applicazione.

L’installer è ora Lua e appartiene a `src/component/media/plugin.lua`. I sorgenti nativi vivono in `src/component/media/osmp/src/`, manifest e metadati in `data/component/media/osmp/`. `make setup SCOPE=lua-applications` riconcilia il registro applicativo. Collisioni, destinazioni redirette e backup simbolici vengono rifiutati prima della pubblicazione; una validazione fallita conserva il runtime installato.
