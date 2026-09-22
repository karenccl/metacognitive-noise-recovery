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
| qs2 | 0.3.1 |
| RcppParallel | 6.2.1 (qs2 dependency) |
| stringfish | 0.19.2 (qs2 dependency) |

`renv` is now active for this project (`renv::init(bare = TRUE)` + `renv::hydrate()`); the full
environment is locked in `renv.lock` (156 packages, `type = "all"` snapshot, captured
2026-09-23). Restore with `renv::restore()`. Full `sessioninfo::session_info()` output not yet
pasted here — the lockfile is the authoritative record of exact versions.

## Verification log

| Date | Check | Result |
|---|---|---|
| 2026-09-23 | `cmdstanr::cmdstan_version()` | 2.36.0 — matches protocol's expected CmdStan 2.36.0 |
| 2026-09-23 | CmdStan compile+sample smoke test (`examples/bernoulli/bernoulli.stan`, 2 chains × 200 warmup/200 sampling) | Passed. Compiled and sampled in ~1.2s; `rhat` ≈ 1.03 for both parameters, no errors. See `docs/analysis_log.md` for the run transcript. |
| 2026-09-23 | Package availability check (`requireNamespace()` for all Day-1 install list) | All present except `qs` (not installed) |
| 2026-09-23 | `qs` install attempt | Failed — `qs` is archived on CRAN for R 4.5.0, superseded by `qs2` (same author). Installed `qs2` 0.3.1 instead. **Deviation:** all references to `qs::qsave()`/`qs::qread()` in code/docs use `qs2::qs_save()`/`qs2::qs_read()` instead; interim files use the `.qs2` extension. |
| 2026-09-23 | `renv::init(bare = TRUE)` + `renv::hydrate()` + `renv::snapshot(type = "all")` | Project library populated by linking 156 already-verified packages from the user library (no re-download); `renv.lock` written recording R 4.5.0 and all package versions/sources (CRAN, plus `cmdstanr` from bbsbayes r-universe, `hmetad` from metacoglab r-universe, `rstan`/`StanHeaders` from stan-dev r-universe). |

**A newer CmdStan version than 2.36.0 is available** (per `cmdstanr` update notice). Not
upgraded — the protocol locks 2.36.0 as the recorded/expected version; revisit only if a
documented reason arises (e.g. a required bugfix), and log any change here.
