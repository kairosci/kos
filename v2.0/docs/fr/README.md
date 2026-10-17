# Documentation OS

[Italiano](../it/README.md) · [English](../en/README.md) · [Français](README.md)

`v2.0/` reste la racine active des versions présentes et futures ; `v1.0/` conserve l’archive d’origine vérifiable. Code, données, tests et documentation restent séparés. La [structure versionnée](versioned-runtime.md) explique les chemins et les exceptions natives de GitHub.

Les [Paramètres](settings.md) regroupent bureau, réseau, Bluetooth, audio et alimentation dans une seule application. La [réactivité](performance.md) décrit les budgets des processus et les limites de la protection OOM. L’[architecture Lua](lua-architecture.md) distingue algorithmes, données, lanceurs et interfaces natives.

La [transition de démarrage](boot-transition.md) conserve chiffrement et récupération. La [migration Arch](arch-migration.md) exige parité fonctionnelle et essais matériels avant de retirer Omarchy. La [feuille de route](../it/roadmap.md) distingue implémentation, installation et validation matérielle ; un test vert ne prouve pas la migration complète.

Depuis la racine du dépôt ou `v2.0/`, `make test` exécute les suites et `make verify` vérifie le système courant. Seule la pipeline `make setup` applique les changements système ; les scopes limitent son domaine. Ne pas appliquer de corrections par copies manuelles ou redémarrages directs de services.

Les instructions normatives des agents et les skills conservent leur source anglaise sous `docs/en/`, exposée par des liens. Les [règles du projet](../en/root/AGENTS.md), la [politique de sécurité](../en/root/SECURITY.md), les [guides des modules](../en/modules/conf/README.md) et le [guide ISO](../en/modules/iso/README.md) conservent les détails techniques et historiques. La licence d’origine n’est ni traduite ni modifiée.
