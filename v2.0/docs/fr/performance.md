# Réactivité du bureau

[Italiano](../it/performance.md) · [English](../en/performance.md) · [Français](performance.md)

Le diagnostic du 16 octobre a observé environ 15 Gio de RAM physique, du swap disque et de la zram déjà actifs, ainsi qu’un processus rust-analyzer de Zed utilisant environ 3,8 Gio résidents et 1 Gio de swap. systemd-oomd avait auparavant arrêté un terminal après une pression prolongée. Il s’agit d’observations, pas d’un benchmark comparatif.

`src/component/performance/editor.lua` calcule la concurrence à partir de `/proc/meminfo` et des processeurs disponibles. `data/component/performance/policy.json` réserve la moitié de la RAM et deux processeurs au reste du système, applique un budget par worker et plafonne le parallélisme. Le résultat observé est trois workers et deux workers de préchauffage du cache. Ce sont des limites de concurrence, pas des limites strictes de mémoire par processus.

Zed reçoit les options natives de rust-analyzer `numThreads`, `cachePriming.numThreads`, `cargo.extraEnv.CARGO_BUILD_JOBS`, `check.extraEnv.CARGO_BUILD_JOBS` et `lru.capacity`. Les diagnostics, macros, vérifications de cibles, autres options LSP et variables personnelles sont préservés. La génération doit réussir avant l’écriture du fichier surveillé, dont l’inode est conservé. Le serveur de langage peut redémarrer ; l’indexation initiale ne mesure pas sa consommation finale. Voir [rust-analyzer](https://rust-analyzer.github.io/book/configuration) et [Zed Rust](https://zed.dev/docs/languages/rust).

`make setup SCOPE=performance` surveille uniquement les slices des applications et tâches de fond, protège les ancêtres de session et réconcilie l’éditeur. Swap et hibernation sont conservés, sans redémarrer compositeur, audio ou réseau. Une charge arbitraire peut toujours épuiser les ressources ; systemd-oomd peut arrêter une application pour préserver la session. Un parallélisme réduit peut rallonger les grosses compilations tout en améliorant l’interaction.

Le même budget est enregistré dans des blocs gérés Bash et `environment.d`, puis activé dans le gestionnaire utilisateur pour les nouvelles applications. Les processus existants conservent leur environnement. Un `--jobs` Cargo explicite peut choisir une autre concurrence ; voir le [Cargo Book](https://doc.rust-lang.org/cargo/reference/environment-variables.html).

La création de répertoires Lua conserve les permissions existantes. La politique du répertoire personnel impose au maximum `750`, sans élargir des droits plus stricts ; `data/core/paths.json` est l’autorité partagée. La [politique détaillée](../en/modules/conf/performance/README.md) et la [feuille de route](../it/roadmap.md) précisent les limites.
