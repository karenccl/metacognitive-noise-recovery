# Analysis Log

Time-stamped log of launched batches, failures, reruns, and deviations from the locked design.

## 2026-09-22

- Scaffolded repository structure per protocol section 2.1 (`code/`, `config/`, `data/`,
  `outputs/`, `docs/`, `tests/`, `manuscript/`, plus `README.md`, `LICENSE`, `CITATION.cff`,
  `.gitignore`, `Makefile`). No simulation or fitting code implemented yet.
- Committed (`869d5e8`) and pushed scaffold to `origin/main`
  (https://github.com/karenccl/metacognitive-noise-recovery).

## 2026-09-23 — Day 0: verify backend

- Confirmed R 4.5.0 installed at `C:\Program Files\R\R-4.5.0`.
- `cmdstanr::cmdstan_version()` returned `2.36.0`, matching the version recorded in the
  protocol. CmdStan path: `C:/Users/chanc/.cmdstan/cmdstan-2.36.0`.
- Ran a CmdStan compile+sample smoke test using the bundled
  `examples/bernoulli/bernoulli.stan` model (2 chains, 200 warmup / 200 sampling draws each,
  seed 12345). Compiled and sampled without error in ~1.2s; `rhat` ≈ 1.03 for `theta` and
  `lp__`, no divergences. Backend verified working end-to-end.
- Checked availability of all packages listed in protocol section 4.1: `cmdstanr`, `brms`,
  `hmetad`, `posterior`, `bayesplot`, `loo`, `tidyverse`, `tidybayes`, `yaml`, `here`,
  `testthat`, `renv` all present. **`qs` is not installed** — flagged as a gap to close before
  Day 2 batch infrastructure (per-cell results are specified to save as `.qs`).
- Full results recorded in `docs/computational_environment.md`.
- Not yet done: `renv::init()` / `renv::snapshot()` to lock the environment (renv is installed
  but the project has no `renv.lock` yet).

### qs → qs2 substitution

- `install.packages("qs")` failed: `qs` is archived on CRAN, not available for R 4.5.0.
- Installed `qs2` 0.3.1 (same author, current maintained successor) plus its dependencies
  `RcppParallel` 6.2.1 and `stringfish` 0.19.2 — all from CRAN binaries, no compile issues.
- **Deviation from protocol section 4.1:** use `qs2::qs_save()` / `qs2::qs_read()` in place of
  `qs::qsave()` / `qs::qread()`; interim per-cell result files use the `.qs2` extension instead
  of `.qs`. Updated `code/00_setup/00_packages.R`, `code/02_fit/run_one_cell.R`, and
  `.gitignore` accordingly. No effect on the scientific design.

### renv::init() and snapshot

- Ran `renv::init(project = ..., bare = TRUE, force = TRUE)` to activate renv for the project
  (creates `.Rprofile`, `renv/activate.R`, `renv/settings.json`, `renv/library/`).
- Ran `renv::hydrate(packages = <Day-1 package list>, update = FALSE)` to populate the project
  library by linking the already-verified packages from the user library (156 packages total,
  including transitive dependencies) — no re-download needed since versions were already
  current.
- Ran `renv::snapshot(type = "all", prompt = FALSE)` to lock every package in the library
  (not just statically-detected dependencies, since most package references in code stubs are
  still commented out at this scaffolding stage). Lockfile written to `renv.lock`, recording
  R 4.5.0 and exact versions/sources for all 156 packages (CRAN plus three r-universe sources:
  `cmdstanr` from bbsbayes, `hmetad` from metacoglab, `rstan`/`StanHeaders` from stan-dev).
- Committed `.Rprofile`, `renv.lock`, and `renv/{.gitignore,activate.R,settings.json}`.
  `renv/library/` stays gitignored (both renv's own `renv/.gitignore` and the project
  `.gitignore` exclude it), consistent with protocol section 2.3.
- **Note for future snapshots:** once real dependencies (`library()`/`::`-calls) land in the
  R scripts, prefer the default `renv::snapshot()` (dependency-scan based) so the lockfile
  reflects only what's actually used; re-run with `type = "all"` deliberately if a full-library
  lock is wanted again.

## 2026-09-23 — Day 1 midday: hmetad docs and design decisions

- No bundled vignettes in `hmetad` 0.2.1; read all exported-function help pages via
  `tools::Rd_db("hmetad")` instead (`sim_metad`, `sim_metad_participant`, `sim_metad_condition`,
  `sim_metad_participant_condition`, `fit_metad`, `aggregate_metad`, `stanvars_metad`, `metad`,
  `metad_pmf`, `type2_probabilities`, `joint_probabilities`, `epred_draws_metad`,
  `metac2_parameters`, `example_data`, `example_model`), plus inspected `example_data()` and
  `aggregate_metad(example_data())` structure directly.
- Ran an empirical check (not just trusting the prose help text, which turned out to have an
  error) of how `M`/`log_M` are scaled across `sim_metad()`, `sim_metad_participant()`, and
  `fit_metad()`. Result: `sim_metad(M=...)` is natural-scale; `sim_metad_participant(mean_M=...,
  allow_negative_values=FALSE)` (the default) is already log-scale; `fit_metad()`'s posterior
  `M` Intercept under the default is `log_M` directly (recovered ≈ −1.06 for a generating
  `log_M = −1`). Full detail and code-level consequences recorded in
  `docs/design_decisions.md`.
- Locked: `metac_absolute = TRUE`, `aggregate = TRUE`, production `log_M` prior
  `normal(0, 1)`, `metac2_parameters(K)` prior `normal(0, 1)`, G2 alternative distribution
  `gumbel_min`. Updated `config/design.yml` accordingly (`fitting:`, `priors:` sections; also
  filled `seed_base`, `sampling.max_treedepth`/escalation, `diagnostics.bulk_ess_min`/
  `tail_ess_min`).
- Wrote the G1 DDM data-generating process as explicit equations + pseudocode (drift/boundary
  decision stage, correlated post-decisional continuation for fixed duration `tau`, signed
  decision-consistent latent quantity `q`, additive Gaussian readout noise `y = q + ε`,
  `ε ~ N(0, σ_c²)`) into `docs/design_decisions.md`, satisfying the Day-1 gate requirement to
  specify G1 in writing before implementation. Explicitly avoids the "`a·RT` as terminal
  evidence" mistake named in protocol section 3.2.
- Wrote the DDM-to-empirical-d′ calibration plan (bisection on drift `v` at fixed `a`/`t0`,
  targeting `d′ ∈ {0.75, 1.5}` within ±0.02, output to
  `outputs/tables/ddm_calibration.csv`) and the σ_c low/medium/high pilot plan. Flagged
  explicitly that raw confidence-category occupancy is **not** a valid degeneracy diagnostic
  here, since the locked rank-based within-subject `K=4` discretisation guarantees ~25% per
  category by construction regardless of σ_c (protocol section 1.4) — the pilot instead checks
  Spearman `ρ(q,y)` and the confidence–accuracy association.
- Added `ddm:` block to `config/design.yml` with starting values (`a=1.5`, `t0=0.3s`,
  `tau=0.3s`, `s=1`, `dt=0.001s`) pending the calibration pilot; `v` and the three `σ_c` values
  remain unset until that pilot is actually run (next: Day 1 afternoon/evening implementation).
- Not yet done: `simulate_g1_ddm.R` implementation, calibration script execution,
  `discretise_confidence()` implementation, unit tests.

## 2026-09-23 — Day 1 afternoon: discretise_confidence() and simulate_g1_ddm()

- Implemented `discretise_confidence()` (`code/01_simulate/discretise_confidence.R`): rank-based
  within-subject `K`-quantile binning via `dplyr::ntile()`. Returns `data` (input + integer
  `confidence` column), `cutpoints` (per-subject `K-1` empirical quantile cut-points plus
  duplicate-value/degenerate-cutpoint counts), `category_counts`, and a one-row `tie_summary`.
  Manually verified: uniform ~n/K category counts by construction; correctly flags all 20 tied
  values and a degenerate cutpoint in an artificial `{0,1}`-repeated test case; errors cleanly
  on missing columns or `NA` in the value column.
- Implemented `simulate_g1_ddm()` (`code/01_simulate/simulate_g1_ddm.R`) per the DGP spec locked
  this morning: two internal helpers, `.ddm_decision_phase()` (vectorised Euler–Maruyama to
  first boundary crossing, `dt = 0.001s` steps, cost scales with only the still-active trials)
  and `.ddm_postdecision_phase()` (continues the same accumulator, unboundaried, for a fixed
  `tau`). `q` is the response-sign-flipped post-decisional evidence relative to the starting
  point; `y = q + N(0, sigma_c^2)`; confidence is binned via `discretise_confidence()`, with its
  diagnostics attached as attributes (`cutpoints`, `category_counts`, `tie_summary`) rather than
  changing the function's primary tibble-of-trials return shape. RNG isolated per call via
  `withr::with_seed()`.
- Manual smoke test (`v=1.2, a=1.5, t0=0.3, tau=0.3, sigma_c=0.5`, 5 × 200 trials): ran in
  0.12s; `rt > t0` always; `correct == (stimulus == response)` always; empirical accuracy 85%.
  At `sigma_c = 0`, `y == q` exactly and confidence is monotonic in `q` per subject (not just
  correlated — checked via `order()` + `is.unsorted()`). At `sigma_c = 50`, Spearman
  `cor(q, y) ≈ 0.03` (chosen to demonstrate near-zero correlation is reachable; the actual
  low/medium/high grid values are still pending the pilot). Same-seed calls are `identical()`.
- Wrote the protocol's required unit tests into `tests/test_discretise_confidence.R` (12 tests:
  category counts, row/column preservation, `K=6` support for the later binning-sensitivity
  analysis, tie/degeneracy flagging, input validation) and `tests/test_simulate_g1_ddm.R` (17
  tests: row/column contract, `sigma_c=0` monotonicity, large-`sigma_c` decorrelation +
  nondegenerate category counts, `aggregate_metad()` compatibility — skipped if `hmetad` isn't
  installed — and seed reproducibility). Ran `testthat::test_dir("tests")`: all pass (the
  `test_data_format.R` stub remains an intentional empty skip, deferred to the Day 2 fit
  wrapper work).
- `renv::status()` shows ~70 packages "recorded but not detected as used" (transitive tidyverse
  deps not yet directly called) — expected given the `type="all"` snapshot; not re-snapshotting
  yet, per the plan already noted above to prefer dependency-scan-based snapshots later.
- Not yet done: DDM calibration pilot (`v`/`σ_c` values still placeholders), `simulate_g0.R`,
  `simulate_g2_gumbel.R`, `validate_generators.R`, `test_data_format.R`.
