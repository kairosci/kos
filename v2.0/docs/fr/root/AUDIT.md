# Registre historique de l’audit

Ce document résume les observations du 12 au 15 octobre 2026, pas l’état actuel ni une certification. L’audit historique relevait 29 suites, 1457 assertions et 166 contrôles. Lynis indiquait un indice de 80 et 22 suggestions ; la version de Semgrep rencontrait six problèmes d’analyse. Quatre profils AppArmor étaient appliqués. Vingt aperçus natifs utilisaient une géométrie de 1800×1012.

arch-audit présentait 23 entrées, dont trois élevées. Les versions installées exigeaient une comparaison aux plages affectées : PAM 1.7.2 contre le correctif 1.7.1 pour CVE-2025-6020 ; DjVu 3.5.30.1 contre 3.5.29 pour CVE-2025-53367 ; libxml2 2.15.4 hors des plages de CVE-2025-6170, CVE-2025-49795, CVE-2025-49794 et CVE-2025-49796. Les vingt autres entrées n’avaient pas été examinées : aucune absence de vulnérabilité n’était établie.

Le 15 octobre, une analyse ClamAV limitée à dix minutes a été interrompue avec des avertissements sur des objets non pris en charge. Cela ne constitue pas une analyse complète saine. Polkit était indisponible pour certains contrôles de cette session ; cette limite historique n’interdit pas les applications ultérieures autorisées par la procédure.

Les chemins temporaires de l’audit original ne sont pas des sauvegardes durables. Évaluer le système actuel nécessite de nouveaux contrôles, l’inventaire réel des paquets et des essais natifs, en distinguant sécurité du dépôt et sécurité de l’installation.
