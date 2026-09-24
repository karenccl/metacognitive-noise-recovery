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

## 2026-09-23 — Day 1 afternoon: DDM calibration and σ_c pilot

- Implemented `code/01_simulate/validate_generators.R`: drift-`v` bisection calibration to
  target `d′` (common-random-numbers seed across iterations for a smooth bisection target), and
  a `σ_c` low/medium/high pilot that reuses one shared `q` realisation (decision + post-decision
  stages don't depend on `σ_c`) and only re-draws readout noise per candidate — fast (full
  script ran in well under a minute for 100k+100k calibration trials and a 20k×12 pilot sweep).
- Calibration results: `d′ = 0.75` → `v = 0.388` (empirical `d′ = 0.733`); `d′ = 1.5` →
  `v = 0.797` (empirical `d′ = 1.500`); both within the ±0.02 tolerance at a shared
  `a = 1.5, t0 = 0.3s` — no per-target boundary/nondecision-time deviation needed. The two
  empirical-`d′` formulas (hit/FA vs. `2·Φ⁻¹(p_correct)`) agreed exactly (0 disagreement),
  ruling out a response-bias bug.
- σ_c pilot (`N=20,000`, calibrated `v` for `d′=1.5`): confirmed empirically that raw
  confidence-category occupancy stays ~25%/category across the whole sweep (as the design
  decisions predicted) and is not a usable diagnostic; used Spearman
  `cor(confidence, correct)` instead, which fell smoothly and monotonically from 0.319 to
  0.037 across 12 candidate `σ_c` values spanning `0.05×SD(q)` to `8×SD(q)`. No tied readout
  values anywhere in the sweep.
- Chosen low/medium/high: `σ_c = 0.291, 0.872, 2.91` (`cor(confidence,correct) = 0.287, 0.176,
  0.062` respectively) — picked as the closest matches to 3 points spanning 85%/50%/15% of the
  observed association range, not evenly-spaced arbitrary numbers.
- Wrote `outputs/tables/ddm_calibration.csv`, `outputs/tables/sigma_c_pilot.csv` (full 12-point
  sweep), `outputs/tables/sigma_c_chosen.csv`. Updated `config/design.yml`
  (`ddm.v_by_dprime_target`, `ddm.sigma_c_values`) and `docs/design_decisions.md` with the full
  results.
- Not yet done: `simulate_g0.R`, `simulate_g2_gumbel.R`, `test_data_format.R`, degeneracy checks
  for the full primary-grid conditions (this pilot used one pseudo-subject at `d′=1.5` only, per
  the calibration plan — the Day-1 gate's broader "validate at primary grid scale" check is
  still pending).

## 2026-09-23 — Day 1 close-out: simulate_g0(), simulate_g2_gumbel(), remaining tests

- Implemented `simulate_g0()` (`code/01_simulate/simulate_g0.R`) using
  `hmetad::sim_metad_participant()` with `sd_dprime = sd_M = sd_c = 0` (no between-subject
  variability on the parameters the known-truth check depends on). Verified: `log_M = -1`
  produces an `M` column of exactly `exp(-1) = 0.3679` for all 4000 simulated rows (20
  participants × 200 trials), and a quick `fit_metad()` recovered posterior `Intercept` ≈
  −1.02 (95% CI [−1.31, −0.81]) — correctly bracketing the generating `log_M`.
- Implemented `simulate_g2_gumbel()` (`code/01_simulate/simulate_g2_gumbel.R`). `hmetad` exports
  no Gumbel-min `lcdf`/`lccdf` (only `normal_lcdf`/`normal_lccdf`), so wrote both, choosing a
  fixed unit-variance scale (`beta = sqrt(6)/pi`) and shifting the location so the distribution's
  mean equals the input `mu` exactly (`nu = mu + gamma*beta`), making `mu` play the same role as
  in the Gaussian case. Verified numerically: `exp(lcdf)+exp(lccdf)==1` everywhere tested;
  numerically-integrated mean/variance from the CDF match `mu`/`1`; `sim_metad()` with these
  functions produced no `NA`s and showed the expected accuracy increase with `dprime`
  (hit rate 0.70→0.81 for `dprime` 0.75→1.5). Full derivation and the still-pending Stan-side
  function requirement for Day 2 fitting recorded in `docs/design_decisions.md`.
- Filled in `tests/test_data_format.R` (17 tests): schema checks (stimulus/response/confidence
  validity) and `hmetad::aggregate_metad()` compatibility for all three generators (G0, G1, G2),
  the G0 known-`M` check, and a Gumbel-min CDF-pair validity check. Ran
  `testthat::test_dir("tests")`: all 46 tests across the three test files pass.
- Day 1 gate substantially closed: all four generator functions
  (`discretise_confidence`, `simulate_g1_ddm`, `simulate_g0`, `simulate_g2_gumbel`) implemented,
  calibrated where required, and tested. Remaining before the full grid: the Day 2 fit wrapper
  (`fit_one_hmetad()`), including the Gumbel-min Stan-side function definitions noted above.

## 2026-09-23 — Day 2 morning: fit_one_hmetad(), extract_fit_summary(), G0 baseline

- Spent significant exploration time on two undocumented `hmetad`/`brms` gotchas before writing
  the wrapper (full detail in `docs/design_decisions.md`): (1) `fit_metad(aggregate=TRUE)`'s
  dots-forwarding is unreliable for specifying a grouping column, so the wrapper aggregates
  explicitly via `aggregate_metad()` and fits with `aggregate=FALSE`; (2) a dpar's prior-class
  spec (`class="<name>"` vs. `class="Intercept", dpar="<name>"`) silently depends on whether
  that dpar has an explicit formula in `bf()`, discovered by trial and error via
  `brms::get_prior()` comparisons since the error message ("priors do not correspond to any
  model parameter") gives no hint which form is expected.
- Implemented `fit_one_hmetad()` (`code/02_fit/fit_hmetad.R`): input validation, a hierarchical
  formula (`(1|participant)` on `mu`/log_M always, on `dprime`+`c` by default, pooled confidence
  thresholds by default — all three configurable), prior construction, `tryCatch`+
  `withCallingHandlers`-wrapped fitting that captures warnings without letting them abort the
  run, and a compact return record (status/elapsed/diagnostics/fit) whether the fit
  succeeds or errors.
- Implemented `extract_fit_summary()` (`code/02_fit/extract_fit_summary.R`): R-hat/ESS restricted
  to population-level (`b_*`) and random-effect-SD (`sd_*`) parameters (excluding the numerous
  per-participant `r_participant[...]` deviations), divergence and max-treedepth-hit counts, and
  a `pass`/`refit` classification (`fail` is deliberately left to the not-yet-built
  `run_one_cell.R`, which owns the escalation/retry history).
- Verified end-to-end on a small/fast config (G0, N=20/T=100, 2 chains × 375 draws,
  `adapt_delta=0.95`): 0 divergences (vs. 3 at brms's default `adapt_delta=0.8` in an earlier
  exploratory run — confirms the locked `0.95` setting matters), `log_M` Intercept ≈ −1.08 (true
  −1), `dprime` ≈ 1.53 (true 1.5), `c` ≈ 0.004 (true 0), correctly flagged `status="refit"` for
  one low-ESS random-effect SD (expected at this tiny smoke-test size). Verified all three
  input-validation error paths (bad confidence code, missing column, bad stimulus code) reject
  before any Stan compilation.
- Added fast (non-MCMC) tests to `tests/test_data_format.R`: `fit_one_hmetad()` validation
  errors, and an `empty=TRUE` build check for `.build_metad_formula()`/`.build_metad_priors()`.
  Deliberately did *not* add a full MCMC-fitting test to the automated suite (a single fit takes
  1-2+ minutes even at reduced settings) — the G0 baseline fit itself is this step's real
  correctness check, run manually and logged here, per the protocol's own Day 2 morning wording
  ("do not overinterpret one fit").
- Updated `config/design.yml`: `fitting.aggregate` corrected to `false` (was stale from the
  original `aggregate=TRUE` plan); added `fitting.hierarchical_dprime_c` (`true`) and
  `fitting.hierarchical_thresholds` (`false`).
- Launched the actual Day-2 G0 baseline fit at full production settings (4 chains, 1000+1000
  warmup/sampling, `adapt_delta=0.95`, `max_treedepth=12`) on N=20/T=100, `dprime_target=1.5`,
  `log_M=-1`.
- **Result: clean pass.** Elapsed 195.1s (~3.25 min) — much faster than the small-config
  smoke-test timing suggested, and a useful first data point for the Day 2 midday compute
  benchmark (aggregation collapses each participant's trials to one count row, so cost scales
  mainly with N-participants/hierarchical units, not directly with T-trials). Diagnostics:
  `status="pass"`, max R-hat 1.006, min ESS(bulk/tail) 1357/1862, 0 divergent transitions, max
  treedepth used 6 (well under the 12 limit), no warnings. Recovery: `log_M` Intercept −0.864
  (95% CI [−1.241, −0.561], known truth −1 inside the interval), `dprime` 1.506 (true 1.5), `c`
  −0.018 (true 0), all six threshold-gap intercepts near their generating −1. Consistent with a
  single illustrative run per the protocol's own caution not to overinterpret one fit. Saved
  the full fit object to `outputs/reports/g0_baseline_fit_result.rds` (gitignored, local only).
- **Day 2 morning deliverable complete:** `fit_one_hmetad()`/`extract_fit_summary()` implemented
  and the G0 baseline confirms the whole pipeline (simulate → aggregate → hierarchical fit →
  diagnose → recover) works end-to-end.

## 2026-09-23 — Day 2 midday: compute benchmark, batch infrastructure, replication decision

- Benchmarked production-settings fits across all 4 N/T corners (20/40 × 100/400): 195.1s,
  140.7s, 243.6s, 247.1s respectively. Confirms cost tracks N (hierarchical units), not T
  (aggregation collapses trials to per-participant counts before fitting).
- **Found `fit_one_hmetad()` wasn't passing `cores` to `brm()`**, so 4 chains ran single-core by
  default. Added `cores` arg (default `= chains`). Re-benchmarked the largest cell: 247.1s →
  123.9s (~2x), same clean diagnostics. Pure efficiency fix, no scientific effect.
- Full-grid projection: 72 unique fit-cells/rep × ~2.07 hours/pass ≈ 62 hours (2.6 days) at 30
  reps/cell run strictly sequentially (one fit at a time).
- **Consulted the user** on replication count vs. compute time, given this is a genuine
  resource/timeline tradeoff with real Monte Carlo precision consequences (protocol explicitly
  allows dropping to 20 or 15 reps). Chose: keep 30 reps/cell, add concurrent batch dispatch
  instead of reducing precision.
- Implemented `code/00_setup/02_create_grid.R`: builds `config/grid.csv` with `grid_id`,
  `cell_id` (shared between a G2 cell's two fit-variant rows so they use the *same* simulated
  dataset, per protocol section 3.3's "two fits per generated dataset"), deterministic
  `sim_seed`/`fit_seed` derived from `seed_base` + stable row indices. Generated the real
  grid: 2160 rows over 1800 unique cells (360 G0 + 1080 G1 + 360 G2 cells → 720 G2 fit rows).
- Implemented `code/02_fit/run_one_cell.R`: resumable (skips existing output), simulates +
  fits one grid row, with one escalation retry (config's `sampling.escalation` settings) if
  `extract_fit_summary()` flags `"refit"`, downgrading to `"fail"` if the retry doesn't clear
  the flags either. Wrapped in `tryCatch()` so simulation/fitting errors (e.g. the known-missing
  Gumbel-min Stan functions for G2 "correct") are saved as structured `status="error"` records,
  not crashes. Saves via `qs2::qs_save()` (verified `qs2::qs_save()`/`qs2::qs_read()` are the
  correct function names — confirmed by listing the package namespace and a round-trip test).
- Implemented `code/02_fit/run_grid.R`: reads `config/grid.csv`, filters to pending
  (not-yet-saved) rows, and runs up to `execution.max_concurrent_fits` (`5`) `run_one_cell.R`
  subprocesses at once via `processx`, polling every 2s and launching a replacement as each
  slot frees up.
- **Smoke-tested the full batch pipeline twice** (protocol's Day-2 gate): once sequentially
  (4 tiny N=3 rows: g0 fail, g1 fail [both expected — hierarchical SDs are barely identifiable
  at N=3, a small-sample artefact of the deliberately tiny smoke size, not a bug], g2
  misspecified pass, g2 correct/gumbel **error** with the exact predicted message —
  `undeclared identifier "gumbel_min_lccdf"` — confirming the documented Day-2 Stan-function
  gap); once with concurrent dispatch (6 rows, `max-concurrent=3`): pool correctly held at 3,
  backfilled on completion, all 6 finished with correct statuses, no crashes. All outputs
  verified readable via `qs2::qs_read()` with sensible metadata. Cleaned up smoke-test
  artifacts from `data/interim/` afterward (gitignored, but tidied for clarity).
- **Day 2 midday deliverable complete.** Not yet done: actually launching the full production
  grid (~12-13 hours projected at 30 reps/cell with 5-way concurrency); the Gumbel-min Stan
  functions needed before any G2 "correct" fit can succeed.

## 2026-09-23 — Close G2 gap: Gumbel-min Stan functions

- User chose (given launch-order tradeoffs discussed above): implement the missing Gumbel-min
  Stan functions before launching the full grid, rather than launching G0/G1 now and G2 later —
  avoids permanently recording 360 G2-"correct" cells as errored (run_one_cell.R's resumability
  check is file-existence-based, so a launch-then-fix approach would have required manually
  deleting those specific output files afterward).
- Added `gumbel_min_stanvars()` to `code/01_simulate/simulate_g2_gumbel.R`, matching the R-side
  `gumbel_min_lcdf()`/`gumbel_min_lccdf()` parameterisation exactly (`beta=sqrt(6)/pi`,
  `nu=mu+euler_gamma*beta`), using Stan's built-in `log1m_exp()`. Wired into
  `code/02_fit/run_one_cell.R` via `extra_stanvars` for the G2 "correct" fit variant only.
- Verified end-to-end: previously errored at Stan compile time ("undeclared identifier
  gumbel_min_lccdf"); now compiles and samples. Test fit (N=20/T=100, `log_M=-1`, reduced
  2-chain/400-draw settings for speed) recovered `log_M` ≈ −0.80 (95% CI [−1.05,−0.58], true −1
  near the CI edge — expected at this reduced size). `status="refit"` at this size also
  expected; production settings should resolve it.
- Added a fast `empty=TRUE` regression test to `tests/test_data_format.R` for
  `gumbel_min_stanvars()`. Full suite re-run: all pass.
- **All three generators now have a working, tested fitting path. Ready to launch the full
  production grid** (2160 rows, `config/grid.csv`, ~12-13 hours projected with 5-way
  concurrency). Launching next.

## 2026-09-23 — Production run stopped, revised, relaunched

- **Launched the full grid** (2160 rows, 30 reps/cell, 5-way concurrency). After producing 16
  results (all G0, all pass), **user stopped the run** to make the changes below before
  committing further compute — measured throughput was ~52 fits/hour at 5-way concurrency
  (thermal-throttled well below the ~124s/fit `cores=4` benchmark's ~145 fits/hour theoretical
  rate), which projected to 41+ hours for 30 reps rather than the earlier ~12-13 hour estimate.
- **Deleted the 16 stale result files** (old full-`brmsfit` format, produced before the format
  change below) so every cell reruns cleanly.
- **Replications 30 → 20** in `config/design.yml`. Rationale (full version in
  `docs/design_decisions.md`): RQ1 is an ordinal/monotonicity question with adequate bias MCSE
  (~0.04) at 20 reps; per-cell CI coverage is imprecise at any feasible rep count regardless, so
  the plan is to pool coverage across G0 cells (MCSE ~1.3%) and report it with MCSE rather than
  per-cell. Regenerated `config/grid.csv`: now 1440 rows (240 G0 + 720 G1 + 480 G2 fit rows over
  1200 unique cells).
- **Pre-registered the failed-fit handling rule** in `docs/design_decisions.md`, before any
  production-scale results exist: primary analysis includes `pass` + `fail` (flagged, never
  silently pooled); sensitivity analysis uses `pass`-only; `error` rows are excluded from
  parameter-estimate analyses and instead reported as convergence failures in RQ3 (failure-rate
  denominator + per-condition tabulation).
- **Slimmed `run_one_cell.R`'s output format.** Added `extract_b_sd_draws()` (posterior draws for
  `b_*`/`sd_*` parameters only, mirroring `extract_fit_summary()`'s own focal-parameter
  selection), `summarise_epred()` (per-cell mean/median/95%-interval summary of
  `hmetad::epred_draws_metad()`, not the raw ~2.5M-row-at-N=40 per-draw output), and
  `add_g2_extras()` (computes `brms::loo()` — confirmed working out-of-the-box, one LOO
  observation per participant — and the epred summary, for **both** G2 fit variants, since G2's
  purpose is comparing them). The full `brmsfit` is now kept only for `rep_id <=
  execution.keep_full_fit_max_rep_id` (locked at 2); every other row gets the compact record.
  Verified on a 5-row smoke grid mixing `rep_id` 1 and 3: `rep_id<=2` files ≈4.5MB (full fit
  kept), `rep_id=3` files ≈370KB (compact only) — roughly a 12x reduction for the ~90% of
  replications (18/20) that don't need the full fit. Confirmed `draws_b_sd` (4000×15, exactly the
  9 population intercepts + 3 random-effect SDs + draw-index columns), `agg` (aggregated observed
  counts, 10 rows for N=10), and G2's `loo`/`epred_summary` (160 rows = 10 participants × 16
  cells, with mean/median/q025/q975) all populated correctly, including for the one `status="fail"`
  smoke row (a flagged fit's LOO/PPC are still informative, so these are computed regardless of
  status as long as a fit object exists).
- **Run order G1 → G0 → G2**: changed `code/00_setup/02_create_grid.R`'s cell-ordering `arrange()`
  to `factor(generator, levels = c("g1","g0","g2"))`. Verified in the regenerated `config/grid.csv`:
  720 G1 rows first, then 240 G0, then 480 G2.
- **Added `.gitattributes`** (`* text=auto eol=lf`) to stop CRLF/LF churn on `renv.lock` and other
  text files. Added the `cores=4` largest-cell benchmark row (123.9407s) to
  `outputs/tables/compute_benchmark.csv` with a new `cores` column distinguishing it from the
  four `cores=1` rows already there.
- Full `testthat::test_dir("tests")` re-run after all changes: all pass.
- **Relaunching** the full grid now (1440 rows, 20 reps/cell, G1→G0→G2 order, compact output
  format). Will report fits/hour and projected finish time after 1 hour, and try
  `max_concurrent_fits = 4` if throughput isn't meaningfully above ~50/hour.
- Launched 2026-09-23 19:21:46. Shortly after, a process-tree check (to compute the 1-hour
  throughput report) showed 19 R processes and briefly looked like a duplicate orchestrator was
  running from the earlier (user-)stopped launch. Traced it fully before taking any action: it
  was one legitimate `run_grid.R` plus its expected process tree
  (orchestrator → 5 concurrent `run_one_cell.R` → 4 `cores` workers each); the apparent
  "second orchestrator" was a `powershell → Rscript → cmd → Rscript` wrapper chain for the same
  single background task, invisible as a single unit in an `Rscript.exe`-only process filter.
  No process was killed; throughput was confirmed healthy from file timestamps (ground truth)
  rather than process state. Recorded here as a reminder that process-tree diagnosis on Windows
  through nested shell wrappers needs the full parent chain, not a name-filtered process list,
  before concluding something is duplicated.
- Checked in periodically through the run (file count + `qs2::qs_read()` status tally + process
  count): throughput held in a 56-63 fits/hour band throughout (thermal-throttled somewhat below
  the raw benchmark's ~145/hour theoretical rate at 5-way concurrency, but consistently well
  above the ~50/hour decision threshold, so `max_concurrent_fits` was never changed from 5).

## 2026-09-24 — Production grid run complete

- **Finished 2026-09-24 21:28:53** (last file written). Total wall time from launch: **~26.1
  hours** (vs. the ~12-13 hour best-case projection from the `cores=4` benchmark — the gap is
  thermal throttling under sustained 5-way-concurrent load, not a bug; throughput was checked
  repeatedly during the run and never dropped below ~56/hour, so no intervention was made).
  Average throughput over the full run: 1440 fits / 26.12 hours ≈ 55.1 fits/hour.
- **Final tally: 1440/1440 grid rows completed. 1437 `pass`, 3 `fail`, 0 `error`.**
  - G0: 240/240 (239 pass, 1 fail)
  - G1: 720/720 (720 pass, 0 fail) — the primary-question generator completed with a perfect
    pass rate
  - G2: 480/480 (478 pass, 2 fail)
  - 154/1440 (10.7%) needed the escalation retry (adapt_delta 0.99, max_treedepth 14) before
    reaching their final status.
  - Elapsed time per fit: median 265.8s, mean 268.1s, max 1514.3s (one outlier, not
    investigated further here — a candidate for the Day-3/4 diagnostics summary to flag by
    condition).
- Per the pre-registered failed-fit rule (above): the 3 `fail` rows stay in the primary analysis,
  flagged; a pass-only sensitivity analysis will check whether they change any conclusion. Zero
  `error` rows means there is nothing to fold into the RQ3 convergence-failure tabulation beyond
  these 3 flagged fits (a very low failure rate at N≥20, consistent with the G0 baseline's clean
  behavior on Day 2).
- Confirmed 0 lingering R processes after completion (clean shutdown, no orphaned workers).
- **Not yet done:** compiling/aggregating the 1440 individual `data/interim/*.qs2` result files
  into the compact processed products in `data/processed/` (protocol's Day 3 morning task,
  `code/03_recovery_analysis/compile_results.R`, not yet implemented) — that is the next step
  before any recovery metrics, figures, or the report can be produced.
