# Sicurezza

Segnalare le vulnerabilità in privato tramite [GitHub Security Advisories](https://github.com/kairosci/os/security/advisories/new), evitando password, token, chiavi e dati personali nei ticket pubblici. Il ramo supportato è main; le versioni pubblicate restano disponibili come storia, non come promessa di manutenzione indipendente.

L’automazione gratuita controlla revisioni pubblicate e pull request mediante azioni fissate a revisioni immutabili e ambiente Arch. I controlli delle dipendenze considerano vulnerabilità moderate o superiori; Trivy e CodeQL applicano le proprie soglie alte o superiori. I risultati coprono la revisione esaminata, non i pacchetti installati o modifiche locali non pubblicate.

L’automerge delle patch Dependabot è limitato a bot verificato, commit firmati, aggiornamenti patch e controlli superati; la verifica periodica non autorizza l’esecuzione con scrittura del codice arbitrario delle PR. Cambiamenti major, minor o non conformi richiedono revisione.

Sul sistema, arch-audit, ClamAV, Lynis, AppArmor e gli altri strumenti producono evidenze distinte. I log possono contenere dati sensibili e richiedono accesso appropriato. Un esito positivo non certifica assenza di malware, CVE, fughe di informazioni o compromissioni. L’applicazione delle correzioni conserva autenticazione, rete, audio e possibilità di recupero.
