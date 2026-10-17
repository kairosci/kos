# Feuille de route Lua

Le [registre des états](../it/roadmap.md) constitue l’unique autorité pour l’achèvement des sprints. Ce guide décrit la feuille de route en français sans dupliquer les indicateurs d’état.

Conserver l’archive Bash vérifiée sous `v1.0/`, puis remplacer algorithmes et tests par des composants Lua dans `v2.0/src/`. Commandes, politique linguistique, catalogues, destinations des applications et règles de rendu appartiennent à `data/`. Les lanceurs essentiels appartiennent à `script/` ; les interfaces des plateformes conservent leur format natif.

Le parcours couvre les primitives du moteur, l’analyse et le rendu du démarrage chiffré, les configurations graphiques, le fond d’écran, Paramètres, les ressources de l’éditeur, les paquets, la sécurité, l’énergie, la maintenance, la vérification et la session. Remplacer les appelants installés après validation comportementale. `make setup` reste l’unique voie d’application.

L’installation du menu Herdr et de son raccourci Hyprland géré, du préréglage EasyEffects et de la configuration GTK utilise désormais des composants d’application Lua et des portées dédiées de configuration. Le registre italien indique l’état actuel.

Le sprint final supprime les algorithmes shell et l’ancienne structure après remplacement équivalent. `migration-report` examine tout le dépôt, y compris les fichiers nouveaux et sans extension ; `verify-full-lua` échoue tant que des algorithmes historiques restent actifs. Déplacer des fichiers ou déléguer Bash depuis Lua ne suffit jamais.

L’indépendance Arch exige des preuves par capacité, un moteur autonome, démarrage à froid réel, veille, déverrouillage chiffré et récupération. Conserver Limine, noyaux fonctionnels et secours jusqu’à réussite. Tests et noms de paquets ne prouvent pas la parité matérielle. Les guides publics existent en it, en et fr ; instructions opérationnelles et licences gardent leur source canonique partagée.

Le provisionnement des paquets par défaut lit désormais une politique validée et installe les paquets manquants des dépôts officiels et de l’AUR avec Lua. L’étape setup reste l’unique voie d’application au système ; les groupes facultatifs conservent leur gestion tolérante des échecs.

Le sprint pare-feu transfère à Lua l’application de la politique UFW et la vérification de son état. Les valeurs par défaut, les ports, les permissions des règles et l’état du service sont contrôlés depuis les données canoniques ; toute dérive échoue explicitement. Les autres politiques de sécurité restent à migrer.

La politique sysctl, le verrouillage kexec et les limites des dumps mémoire utilisent désormais un composant Lua avec des données externes et une publication idempotente. La vérification compare les fichiers persistants et 19 valeurs actives ; les autres politiques de sécurité restent à migrer.

Les politiques d’authentification et SSH sont désormais des données externes appliquées par Lua. La migration PAM conserve les commentaires et les autres règles, supprime les options en ligne conflictuelles, garde une sauvegarde initiale et rejette les piles non prises en charge. SSH valide les fichiers temporaires avant publication et vérifie ses trois fichiers gérés.

La politique des services systemd passe à Lua. Les fichiers journald et resolved proviennent des données canoniques, et la vérification contrôle leur contenu ainsi que l’état désactivé des services et sockets gérés.

L’audit hebdomadaire exécute désormais Lynis, rkhunter, ClamAV et arch-audit via Lua. Le timer systemd et Cronie ne sont jamais activés simultanément ; le lanceur, les unités, la configuration logrotate et l’amorce minimale sont vérifiés depuis les données canoniques. Les alertes arch-audit entraînent un échec à examiner.

La pile de sécurité utilise désormais Lua et des données externes pour l’installation des paquets, les règles d’audit, la configuration Fail2ban et les profils AppArmor, avec vérification explicite. USBGuard ne génère une politique initiale qu’en l’absence de configuration non vide et conserve les règles existantes ; les capacités matérielles restent à vérifier sur l’appareil.

Le basculement DNS fonctionne désormais en Lua avec `systemd-resolved`, sans appeler le runtime Omarchy. Seuils, délai, fournisseurs et adresses proviennent des données canoniques ; la vérification contrôle la configuration active et le service.
