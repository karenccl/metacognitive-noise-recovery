# Computational Environment

Captured 2026-09-25 from the machine that produced the results (session info from a fresh
`Rscript` in the project directory, so `renv` was active). The authoritative package record is
`renv.lock`; this file adds what the lockfile does not record.

## Hardware and OS

- Intel Core Ultra 7 155H (laptop CPU), 16 physical / 22 logical cores, 31.4 GB RAM
- Windows 11 x64 (build 26200), time zone Asia/Hong_Kong
- The production grid ran 5 concurrent fits × 4 chains (`execution.max_concurrent_fits: 5`,
  `cores = chains`), about 55 fits/hour over ~26 hours, below the short-benchmark rate. Sustained
  all-core load on a laptop part is the likely reason (thermal throttling was suspected during the
  run but not measured).

## Stan backend actually used — read this

**All production fits were sampled with the `rstan` backend (rstan / StanHeaders 2.36.0.9000,
i.e. the Stan 2.36 series), not CmdStan.** This was confirmed by reading `fit$backend` from saved
fits (grid_ids 901, 561, 1321: `rstan`, class `stanfit`). `brms.backend` is not set anywhere in
the code (the only occurrences are a commented-out line in `code/00_setup/00_packages.R` and the
README), so `brms` used its default. CmdStan 2.36.0 and `cmdstanr` 0.8.0 are installed and passed
a Day-0 smoke test run directly through `cmdstanr`, but no `brms` model in this project was
sampled by them. Earlier notes that describe the backend as CmdStan (Day-0 log, first version
of this file, report draft) were wrong on this point and have been corrected.

Consequences: the model and Stan version are the same either way, so the statistical results
are not in question, but sampling output is not bit-identical across backends. To match the
published results, leave `brms.backend` unset (or set it to `"rstan"`); do not set it to
`"cmdstanr"`. Recommended hardening (not done, since it would change fitting code after the
results were produced): pass `backend = "rstan"` explicitly in `fit_one_hmetad()`.

## Software

R 4.5.0 (2025-04-11 ucrt). `sessioninfo` is not installed, so this is base `sessionInfo()` plus
the versions of the packages the pipeline calls directly.

| Package | Version | Role |
|---|---|---|
| hmetad | 0.2.1 | meta-d′ model, simulators, `aggregate_metad`, `epred_draws_metad` (metacoglab r-universe) |
| brms | 2.23.0 | model fitting front end |
| rstan / StanHeaders | 2.36.0.9000 | **sampler used** (stan-dev r-universe) |
| cmdstanr / CmdStan | 0.8.0 / 2.36.0 | installed and smoke-tested; not used by the fits |
| posterior | 1.7.0 | draws handling, R-hat/ESS |
| loo | 2.8.0 | PSIS-LOO, `loo_compare` |
| dplyr / tidyr / purrr / readr | 1.2.0 / 1.3.2 / 1.0.4 / 2.1.5 | data handling |
| ggplot2 / gridExtra | 4.0.1 / 2.3 | figures |
| withr | 3.0.2 | scoped seeding |
| qs2 | 0.3.1 | per-fit result files (replaces archived `qs`) |
| processx | 3.8.6 | concurrent grid runner |
| yaml / here | 2.3.10 / 1.0.2 | config, paths |
| testthat | 3.3.2 | unit tests |
| renv | 1.2.2 | environment lock |

`sessionInfo()` (attached and loaded packages after `library(hmetad); library(brms); library(cmdstanr)`):

```text
R version 4.5.0 (2025-04-11 ucrt)
Platform: x86_64-w64-mingw32/x64
Running under: Windows 11 x64 (build 26200)
Matrix products: default
  LAPACK version 3.12.1
locale: LC_COLLATE/LC_CTYPE/LC_MONETARY/LC_TIME = English_United Kingdom.utf8; LC_NUMERIC = C
time zone: Asia/Hong_Kong
attached base packages: stats graphics grDevices datasets utils methods base
other attached packages: cmdstanr_0.8.0 hmetad_0.2.1 brms_2.23.0 Rcpp_1.0.14
loaded via a namespace (and not attached):
 Matrix_1.7-3 bayesplot_1.14.0 jsonlite_2.0.0 gtable_0.3.6 dplyr_1.2.0 compiler_4.5.0
 renv_1.2.2 tidyselect_1.2.1 stringr_1.6.0 parallel_4.5.0 scales_1.4.0 lattice_0.22-6
 coda_0.19-4.1 ggplot2_4.0.1 R6_2.6.1 Brobdingnag_1.2-9 generics_0.1.4 distributional_0.5.0
 knitr_1.50 backports_1.5.0 checkmate_2.3.2 tibble_3.3.0 pillar_1.10.2 RColorBrewer_1.1-3
 posterior_1.7.0 rlang_1.3.0 stringi_1.8.7 xfun_0.52 S7_0.2.1 RcppParallel_6.2.1 cli_3.6.5
 magrittr_2.0.4 ps_1.9.1 rstantools_2.5.0 processx_3.8.6 grid_4.5.0 mvtnorm_1.3-3
 lifecycle_1.0.5 nlme_3.1-168 vctrs_0.7.2 evaluate_1.0.5 tensorA_0.36.2.1 glue_1.8.0
 farver_2.1.2 bridgesampling_1.2-1 abind_1.4-8 matrixStats_1.5.0 tools_4.5.0 loo_2.8.0
 pkgconfig_2.0.3
```

CmdStan 2.36.0 was installed at `~/.cmdstan/cmdstan-2.36.0` during setup (a newer CmdStan exists
upstream and was deliberately not installed), but it was not used for any reported fit: all fits ran
on the default `rstan` backend, so CmdStan is not needed to reproduce the results. `getOption("brms.backend")` is `NULL` in a fresh session.
`renv::status()` reports many packages as "recorded but not used" because the lockfile was
written with `type = "all"` before real code existed (see `docs/analysis_log.md`); this is
over-inclusion, not missing packages.

## Verification log

| Date | Check | Result |
|---|---|---|
| 2026-09-23 | `cmdstanr::cmdstan_version()` | 2.36.0 |
| 2026-09-23 | Bundled bernoulli model through `cmdstanr` directly (2 chains × 200+200) | Passed in ~1.2 s. Verifies CmdStan itself; does not verify the `brms` backend |
| 2026-09-23 | Package availability for the initial install list | All present except `qs` |
| 2026-09-23 | `qs` install | Failed (archived on CRAN); installed `qs2` 0.3.1 instead (deviation) |
| 2026-09-23 | `renv::init(bare = TRUE)` + `hydrate` + `snapshot(type = "all")` | 156 packages locked in `renv.lock` |
| 2026-09-25 | `fit$backend` in saved production fits | `rstan` (see above) |
