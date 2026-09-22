# Computational Environment

Verified 2026-09-23 (Day 0 backend check).

- R version: R version 4.5.0 (2025-04-11 ucrt)
- Operating system: Windows 10 x64 (host reports Windows 11 Home 10.0.26200)
- `cmdstanr::cmdstan_version()`: 2.36.0
- CmdStan installation path: `C:/Users/chanc/.cmdstan/cmdstan-2.36.0`
- CPU: 22 logical cores (`parallel::detectCores()`)

## Package versions

| Package | Version |
|---|---|
| cmdstanr | 0.8.0 |
| brms | 2.23.0 |
| hmetad | 0.2.1 |
| posterior | 1.7.0 |
| bayesplot | 1.14.0 |
| loo | 2.8.0 |
| tidyverse | 2.0.0 |
| tidybayes | 3.0.7 |
| yaml | 2.3.10 |
| here | 1.0.2 |
| testthat | 3.3.2 |
| renv | 1.2.2 |
| qs | **not installed** — required by protocol section 4.1 for atomic result storage (`data/interim/*.qs`); install before Day 2 batch infrastructure |

Full `sessioninfo::session_info()` output not yet captured; re-run and paste after `renv::init()` /
`renv::snapshot()` so the lockfile and this log stay consistent.

## Verification log

| Date | Check | Result |
|---|---|---|
| 2026-09-23 | `cmdstanr::cmdstan_version()` | 2.36.0 — matches protocol's expected CmdStan 2.36.0 |
| 2026-09-23 | CmdStan compile+sample smoke test (`examples/bernoulli/bernoulli.stan`, 2 chains × 200 warmup/200 sampling) | Passed. Compiled and sampled in ~1.2s; `rhat` ≈ 1.03 for both parameters, no errors. See `docs/analysis_log.md` for the run transcript. |
| 2026-09-23 | Package availability check (`requireNamespace()` for all Day-1 install list) | All present except `qs` (not installed) |

**A newer CmdStan version than 2.36.0 is available** (per `cmdstanr` update notice). Not
upgraded — the protocol locks 2.36.0 as the recorded/expected version; revisit only if a
documented reason arises (e.g. a required bugfix), and log any change here.
