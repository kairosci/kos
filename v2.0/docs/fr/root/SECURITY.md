# Sécurité

Signaler les vulnérabilités en privé via [GitHub Security Advisories](https://github.com/kairosci/os/security/advisories/new), sans publier mots de passe, jetons, clés ou données personnelles. La branche prise en charge est main ; les anciennes publications restent des archives, sans promesse de maintenance indépendante.

L’automatisation gratuite analyse les révisions publiées et pull requests avec des actions fixées à des révisions immuables et un environnement Arch. Les contrôles de dépendances considèrent les vulnérabilités modérées ou supérieures ; Trivy et CodeQL appliquent leurs seuils élevés ou supérieurs. Les résultats concernent la révision analysée, pas les paquets installés ni les changements locaux non publiés.

La fusion automatique des correctifs Dependabot est limitée au bot vérifié, aux commits signés, aux versions patch et aux contrôles réussis. La vérification périodique n’autorise pas l’exécution avec écriture du code arbitraire des PR. Les autres mises à jour nécessitent une revue.

Sur la machine, arch-audit, ClamAV, Lynis, AppArmor et les autres outils produisent des preuves distinctes. Les journaux peuvent contenir des données sensibles et exigent un accès adapté. Un résultat positif ne certifie pas l’absence de malware, CVE, fuite ou compromission. Les corrections préservent authentification, réseau, audio et récupération.
