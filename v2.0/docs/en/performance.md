# Desktop responsiveness

[Italiano](../it/performance.md) · [English](performance.md) · [Français](../fr/performance.md)

The October 16 diagnosis observed about 15 GiB physical RAM, existing disk swap and zram, and a Zed rust-analyzer process using about 3.8 GiB resident memory and 1 GiB swap. systemd-oomd had previously terminated a terminal after sustained pressure. These are observations, not comparative benchmarks.

`src/component/performance/editor.lua` derives concurrency from `/proc/meminfo` and online processors. `data/component/performance/policy.json` reserves half of RAM and two processors for the rest of the system, applies a per-worker budget and caps parallelism. The observed result is three workers and two cache-priming workers. These are concurrency limits, not hard per-process memory limits.

Zed receives native rust-analyzer options `numThreads`, `cachePriming.numThreads`, `cargo.extraEnv.CARGO_BUILD_JOBS`, `check.extraEnv.CARGO_BUILD_JOBS` and `lru.capacity`. Personal diagnostics, macros, target checks, other LSP options and environment variables remain preserved. Generation must finish before the watched settings file is written; its existing writer preserves the inode. Changes may restart the language server; initial indexing is not a stable final memory measurement. See [rust-analyzer](https://rust-analyzer.github.io/book/configuration) and [Zed Rust](https://zed.dev/docs/languages/rust).

`make setup SCOPE=performance` applies the existing OOM policy only to application and background slices, protects session ancestors and reconciles the editor. It preserves swap and hibernation and does not restart the compositor, audio or network. Arbitrary workloads can still exhaust resources; systemd-oomd may terminate an application to preserve the session. Lower parallelism can make large builds slower while improving interaction.

The same budget is written to managed Bash and `environment.d` blocks while preserving unrelated content, then activated in the user manager for new applications. Existing processes keep their old environment. Explicit Cargo `--jobs` overrides can select different concurrency; see the [Cargo Book](https://doc.rust-lang.org/cargo/reference/environment-variables.html).

Lua directory creation preserves existing permissions. The home policy caps permissions at `750` without widening stricter modes; `data/core/paths.json` is the shared authority. See the detailed [resource policy](modules/conf/performance/README.md) and the [migration roadmap](../it/roadmap.md).
