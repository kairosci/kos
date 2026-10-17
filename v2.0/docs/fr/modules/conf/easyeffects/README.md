# EasyEffects

Le préréglage OS Subwoofer ajoute des harmoniques aux basses fréquences sans prétendre modifier les capacités physiques des haut-parleurs. Il prévoit une réserve à l’entrée, un filtre passe-haut à 60 Hz, un traitement harmonique sous 110 Hz et un limiteur à −2 dB. Il ne garantit pas l’absence de distorsion à tout volume et sur tout appareil.

Le composant Lua installe le préréglage `OS-Subwoofer` et le démarrage automatique natif avec `make setup SCOPE=easyeffects` (ou `make easyeffects`). Il ne l’active que dans une session utilisateur disponible et vérifie le préréglage chargé. Les exécutions suivantes préservent tout autre préréglage choisi explicitement. Les bases EasyEffects d’origine sont sauvegardées de manière privée dans l’état OS avant la première application ; les préréglages existants restent disponibles.

L’installation conserve la sourdine, le périphérique audio et les effets du microphone. Les sauvegardes personnelles restent privées. Les paramètres appartiennent aux données du composant ; la vérification doit utiliser une version native prise en charge, notamment EasyEffects 8.2.9.
