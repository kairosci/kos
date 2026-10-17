# Nettoyage historique

Ce sous-projet conserve des outils Bash antérieurs à la migration complète. Il ne constitue pas le chemin d’application habituel : les modifications système passent par `make setup`. La présence des sources n’autorise pas l’exécution séparée des scripts privilégiés.

La politique historique comprend le cache pacman avec deux versions conservées, les paquets orphelins, le journal limité à 200 Mio et deux semaines, les fichiers core de quatorze jours, les temporaires de sept jours et les temporaires persistants de quatorze jours. Elle comprend Flatpak et le cache des polices. Le nettoyage des répertoires personnels concerne aussi les anciens lanceurs, miniatures et la corbeille après trente jours.

Certains chemins historiques traitent les configurations d’applications retirées : leur migration exige d’abord la préservation des données et la vérification de leur propriétaire. L’absence d’un paquet ne suffit pas à autoriser l’effacement du profil. Ces algorithmes restent comptés parmi les composants non migrés.
