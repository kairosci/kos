# Réactivité du bureau

La politique surveille uniquement les slices des applications et des tâches d’arrière-plan. La pression mémoire prolongée est évaluée à 40 % pendant dix secondes, et l’utilisation du swap à 80 %. Les poids CPU privilégient la session avec 200 contre 25 pour l’arrière-plan ; `MemoryLow` protège 512 Mio dans les ancêtres prévus.

La sélection OOM ne doit jamais couvrir toute la session. Le swap et l’hibernation existants sont conservés ; les gestionnaires utilisateur sont rechargés sans redémarrer le bureau ou l’audio. Une intervention OOM peut toutefois terminer un groupe applicatif et perdre des données non enregistrées : ces seuils ne garantissent pas une mémoire illimitée.

Les modèles sous `modules/conf/performance/data/` font autorité. `make setup SCOPE=performance` réconcilie la politique ; les contrôles du système réel restent distincts des tests avec données isolées.
