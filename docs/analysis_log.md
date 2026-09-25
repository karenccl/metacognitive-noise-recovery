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

## 2026-09-24 — Day 3 morning: compile_results.R and G0 recovery summary

- Implemented `code/03_recovery_analysis/compile_results.R`: reads every `data/interim/*.qs2`
  file, extracts a compact per-row summary (grid metadata, status/diagnostics, and a `log_M`
  posterior point summary — mean/median/sd/95% CI — from the compact `draws_b_sd$b_Intercept`
  saved by `run_one_cell.R`), cross-checks the result set against `config/grid.csv` for
  completeness (missing/duplicate/unexpected `grid_id`s — from structured status fields, not
  file presence alone, per protocol section 5), and computes G0 bias/RMSE/coverage/interval-width
  per condition plus a pooled-across-cells coverage estimate (the plan locked when replications
  were revised to 20 — see the 2026-09-23 reps-30→20 entry above).
- **Completeness: perfect.** All 1440 intended grid rows present exactly once; 0 missing, 0
  duplicate, 0 unexpected. Status tally from the compiled table matches the earlier live-progress
  tallies exactly (G0: 239 pass/1 fail; G1: 720 pass/0 fail; G2: 478 pass/2 fail).
- Wrote `data/processed/compiled_results.csv` (1440 rows — the table every downstream script
  should read from now on, instead of re-reading all 1440 `.qs2` files), `g0_recovery_summary.csv`
  (per-condition bias/RMSE/coverage/CI-width, 12 rows), and `g0_pooled_coverage.csv`.
- **G0 recovery results:** RMSE shrinks monotonically with more data within each `d′` level, as
  expected (e.g. `d′=1.5`: 0.173 at N=20/T=100 down to 0.069 at N=40/T=400). **Pooled coverage
  across all 240 G0 replications: 95.8% (95% CI [92.5%, 97.7%]), MCSE 1.3%** — close to the
  nominal 95%, and precise enough to trust (unlike any single cell's coverage, which ranges
  80-100% across the 12 conditions with wide individual CIs, exactly the imprecision problem the
  pooling plan was designed to route around).
- **Observation flagged for the Day 4 prior-sensitivity check, not investigated further now:**
  bias is negative in **all 12 G0 conditions** (range −0.025 to −0.177 on the `log_M` scale,
  i.e. `log_M` is consistently *underestimated* — the model reads subjects as slightly less
  metacognitively efficient than the generating truth). This is the opposite direction from
  simple shrinkage toward the `normal(0,1)` prior's mean of 0 (which would pull estimates of a
  true `log_M=-1` *up*, toward 0, i.e. produce *positive* bias) — so it isn't just prior
  shrinkage, and is worth a closer look when the Day 4 prior-sensitivity sweep runs (comparing
  `normal(0,0.5)`, `normal(0,1)`, `normal(0,2)` should reveal whether the direction/magnitude of
  this bias tracks the prior's width, which would confirm or rule out shrinkage as the
  explanation).
- Full `testthat` suite not re-run for this step (no new sourced functions land in `tests/` —
  `compile_results.R` is a standalone analysis script, consistent with the project's existing
  practice of not unit-testing the batch/analysis-orchestration scripts, only the generator and
  fitting functions they call).

## 2026-09-24 — Day 3 afternoon: compute_primary_metrics.R — RQ1 result

- Implemented `code/03_recovery_analysis/compute_primary_metrics.R`, scoped to G1's ordinal-
  recovery estimands (G0's bias/RMSE/coverage already live in `compile_results.R`).
- **Verified the `agg$N` column-indexing logic before trusting it at scale**: re-simulated one
  G0 cell with its exact grid seed, computed hit/FA rate directly from trial-level `stimulus`/
  `response` columns, and compared against the same quantities derived from
  `aggregate_metad()`'s matrix-column layout (`N_0_1..N_0_8`, `N_1_1..N_1_8`, per the package's
  documented `[R=0,C=K..1; R=1,C=1..K]` ordering per stimulus). Exact match (hit=0.668, FA=0.372
  both ways) before running on all 720 G1 files.
- **Empirical `d′` check**: pooled across all G1 replications, empirical `d′` = 0.743 (target
  0.75, SD 0.036) and 1.50 (target 1.5, SD 0.038) — confirms the DDM generator's calibration
  (locked 2026-09-23) held up consistently across the full production grid, not just the
  original pilot sample.
- Fixed one bug found on first run: a `dplyr::left_join()` with an accidentally-duplicated
  `dprime_target` column selection; corrected and reran clean.
- **G1 primary result (RQ1) — strong, clean support for ordinal recovery**, across all 12
  N×T×`d′` conditions (n=60 replications per condition, 20 per `σ_c` level):
  - **12/12 conditions show the expected negative slope** of `log_M` on `σ_c`
    (range −0.50 to −0.63, all `p` < 1e-21).
  - Spearman `ρ` between `σ_c` and posterior median `log_M`: −0.92 to −0.94 in every condition.
  - **Ordering accuracy** (paired by `rep_id` — note: `σ_c` levels do NOT share simulation
    seeds in this grid, each `(N,T,d′,σ_c,rep)` cell has its own independent `sim_seed`, so this
    is an independent-replicate comparison, not a common-random-numbers one): **11/12 conditions
    at 100%** (20/20 matched reps in perfect `log_M(low) > log_M(medium) > log_M(high)` order),
    one at 95% (19/20).
  - **Separation probabilities** (Mann-Whitney-style, using all replicate pairs rather than only
    matched `rep_id`s): ≥0.965 for every adjacent contrast in every condition, mostly exactly
    1.0.
  - Primary (pass+fail) and pass-only sensitivity results are **identical**, since G1 had a
    100% pass rate (0 fails, 0 errors) across all 720 fits — the flagged-vs-pass-only question
    the pre-registered rule anticipated turned out not to matter for G1.
- Confidence-category marginals confirmed ~25%/category as expected by construction (not a
  degeneracy diagnostic, per the Day-1 design decision); per-replicate tie/cut-point diagnostics
  were not persisted in the compact output format and were not re-audited here (documented
  limitation, validated instead at the Day-1 pilot stage).
- Wrote `data/processed/g1_failure_rates.csv`, `g1_empirical_dprime_check.csv`,
  `g1_primary_metrics.csv`, `g1_sensitivity_metrics.csv`.
- **Bottom line for the report's Results section:** under the specified DDM-type generator,
  estimated static `log_M` declined monotonically as confidence-readout noise increased, with
  near-perfect ordinal recovery — consistent with (but not yet cross-checked against) adequate
  generative fit; that check is the Day 5 PPC task, still pending. Per protocol section 6.2's
  interpretation template, the ordinal-recovery claim alone does **not** yet establish that the
  fitted static meta-d′ model is a generatively adequate account of the full response-confidence
  distribution. G1's `run_one_cell.R` records don't carry PPC precursors (only G2 rows compute
  `loo`/`epred_summary`, per the 2026-09-23 output-format decision) — G1's own posterior
  predictive check (protocol's "G1 low-noise pass" / "G1 high-noise pass/failure" representative
  fits) is a Day 5 task requiring a fresh `epred_draws_metad()` call on a handful of saved fits,
  not yet done.

## 2026-09-24 — Day 4: G2 LOO/ELPD comparison

- Implemented `code/04_ppc_and_comparison/loo_comparison.R`. Verified before trusting it at
  scale: `loo::loo_compare()` on one manually-loaded correct/misspecified pair worked correctly,
  and `dim(loo_object$pointwise) = [20, 5]` for an N=20 fit confirms (again) that one LOO
  observation is one participant's aggregated count vector (5 = the standard `pointwise` columns
  `elpd_loo`/`mcse_elpd_loo`/`p_loo`/`looic`/`influence_pareto_k`, 20 = participants) — stated
  explicitly in the script's own header per protocol's requirement to document the LOO unit
  before interpreting it.
- Paired all 240 G2 cells' `correct`/`misspecified` fits by `(cell_id, rep_id)` — valid because
  both variants of a cell were fit to the **identical** simulated dataset (shared `sim_seed`,
  locked in `code/00_setup/02_create_grid.R`), satisfying `loo_compare()`'s same-data requirement.
- **Pareto k caveat (report prominently, do not paper over):** 12.0% of `correct`-model LOO
  observations and 8.2% of `misspecified`-model observations have `k > 0.7` (PSIS unreliable).
  Mean max-k per fit: 0.79 (correct) / 0.76 (misspecified). No remedy (moment-matching, exact
  K-fold refit of flagged observations) was implemented — this is a stated limitation, not
  silently absorbed into the headline ELPD numbers. The directional conclusion below is treated
  as robust to this (it holds in the overwhelming majority of pairs, not just the reliable
  subset), but exact ELPD magnitudes should be read as approximate.
- **ELPD result: the correctly-specified (Gumbel-min) model is preferred over the misspecified
  (Gaussian) model in 96.2% of all 240 paired comparisons** (72.9% at a >2SE margin). Mean ELPD
  advantage for the correct model grows sharply with more data — from +2.2 (SE 2.7, essentially
  undetectable) at the smallest condition (N=20/T=100/d′=0.75) to +83.1 (SE 11.3, overwhelming)
  at the largest (N=40/T=400/d′=1.5) — the expected pattern: more data both sharpens estimation
  and amplifies a real model-misfit signal.
- **log_M recovery reveals a clean, opposite-direction bias pattern:** the correctly-specified
  model has a small **negative** bias in all 12 conditions (−0.007 to −0.092), matching the same
  direction and rough magnitude already seen in G0 (flagged 2026-09-24 for the Day 4
  prior-sensitivity check) — consistent with this being a general prior/hierarchical-shrinkage
  property of the fitting pipeline, not something specific to G2's distribution. The
  **misspecified** Gaussian fit instead shows a **positive** bias in all 12 conditions (+0.064 to
  +0.195) and uniformly higher RMSE than the correct fit — Gaussian misspecification makes
  subjects look *more* metacognitively efficient than the Gumbel-min-generating truth, the
  opposite direction from the correct model's own small residual bias.
- Wrote `data/processed/g2_pareto_k_by_fit.csv`, `g2_pareto_k_summary.csv`,
  `g2_elpd_comparison.csv` (240 pairs), `g2_elpd_summary.csv` (by condition),
  `g2_log_M_recovery.csv` (24 rows: 12 conditions × 2 variants).
- **Bottom line for the report:** G2 supports the protocol's misspecification-sensitivity
  question clearly — LOO correctly and increasingly favors the true generative distribution as
  data accumulate, and point-estimate bias under misspecification is systematic, sizeable, and
  in a specific (efficiency-inflating) direction, not just noisier. Scale caveat applies as
  locked: this compares `log_M` *within* hmetad's own parameterisation across two fitted
  families on the same data, not a claim that Gaussian- and Gumbel-scale `log_M` are
  substantively identical in general.

## 2026-09-24 — Day 4 midday: prior sensitivity, and revisiting the negative-bias question

- Implemented `code/03_recovery_analysis/prior_sensitivity.R`: refits one representative G0 and
  one representative G1 dataset (N=40, T=200, `d′=1.5`; G1: `σ_c=medium`; rep 1 of each) under
  the three predeclared `log_M` priors (`normal(0,0.5)`, `normal(0,1)`, `normal(0,2)`), using
  the SAME `fit_seed` across all three refits of a generator to isolate the prior's effect from
  sampler RNG noise, and regenerating the identical trial-level dataset from the grid row's own
  `sim_seed` (rather than trying to reuse the compact-format `agg`, which `fit_one_hmetad()`
  can't accept directly since it always aggregates from trial-level data itself).
- Fixed one bug on first run (all 6 fits succeeded, but post-processing crashed): the script
  assumed `fit_one_hmetad()`'s return value has a `draws_b_sd` field, but that extraction is
  actually done by `run_one_cell.R`'s compact-record wrapper, not by `fit_one_hmetad()` itself —
  calling `fit_one_hmetad()` directly (as this script does, bypassing `run_one_cell.R`) returns
  the full `$fit` with no `draws_b_sd`. Fixed by extracting draws directly via
  `posterior::as_draws_df(f$fit)$b_Intercept`. Had to redo all 6 fits (~20 min) since the
  process had already exited after the crash.
- **Results (posterior mean `log_M`, G0 known truth = −1):**

  | Prior | G0 mean | G0 95% CI | G1 mean | G1 95% CI |
  |---|---|---|---|---|
  | `normal(0, 0.5)` | −0.939 | [−1.123, −0.770] | −0.722 | [−0.865, −0.588] |
  | `normal(0, 1)` (production) | −0.958 | [−1.148, −0.794] | −0.733 | [−0.874, −0.607] |
  | `normal(0, 2)` | −0.966 | [−1.172, −0.791] | −0.736 | [−0.882, −0.604] |

  Both generators show the **same monotonic, textbook-shrinkage pattern**: the tighter the
  prior, the more the posterior mean is pulled toward the prior's own mean of 0 (i.e. *less*
  negative). The three priors span only a modest range (G0: −0.939 to −0.966, a 0.027 spread;
  G1: −0.722 to −0.736, a 0.014 spread) relative to the posterior SD (~0.09/0.07) — at N=40/T=200
  the likelihood is reasonably, but not overwhelmingly, informative relative to any of these
  three prior widths. Per protocol's instruction to treat this as an identifiability finding,
  not a defect: this is a normal, expected degree of prior sensitivity, not a warning sign.

- **This corrects/narrows the 2026-09-24 "negative bias, opposite direction from shrinkage" flag
  from the G0-compilation step.** That flag was right that the *direction* is not what naive
  shrinkage-toward-0 alone would produce — and this sweep confirms exactly why: shrinkage toward
  a `normal(·, sd)` prior centered at 0 can only ever pull a posterior mean *toward* 0 (i.e. make
  a true `log_M=-1` estimate *less* negative, which is what all three priors do here relative to
  each other). So the small **negative** aggregate bias seen across G0's 12 conditions
  (−0.007 to −0.092 per condition, in `g0_recovery_summary.csv`/`g2_log_M_recovery.csv`) is not
  something the production `normal(0,1)` prior is *causing* — if anything, moving to an even
  wider (less informative) prior made the single representative G0 fit here *more* negative
  (−0.966 at `sd=2` vs −0.939 at `sd=0.5`), suggesting the underlying likelihood-driven signal
  itself leans slightly negative of truth at this design, and the production prior's mild
  shrinkage toward 0 is *attenuating* that tendency somewhat, not creating it.
  **Not fully explained by this sweep** (a single representative replicate can't resolve a
  small-magnitude, 12-condition-consistent aggregate effect — protocol's own caution against
  overinterpreting one illustrative run applies here too): the residual small negative bias's
  ultimate source (candidates include posterior-mean-of-a-nonlinear-log-link-transform effects,
  or hierarchical partial-pooling behavior on the `sd_participant` components) is left as a
  documented open question / limitation for the final report, not chased further within the
  remaining project timeline.
- Wrote `data/processed/prior_sensitivity_summary.csv` and `outputs/figures/prior_sensitivity.png`
  (violin + posterior median/95% CI by prior, faceted by generator, with the G0 truth line shown
  only on the G0 facet since G1 has no single true `log_M` by construction).

## 2026-09-25 — Verification: prior_sensitivity.R reuses the exact original grid data/fit

User asked (correctly) to verify whether `prior_sensitivity.R`'s two "representative rows" are
freshly-generated data under a new/different seed, or a reproduction of the exact data/fit
already in the production grid — because the answer changes what the figure's absolute distance
from the truth line is allowed to mean.

**Verified empirically, not just by re-reading the code:** compared the script's
`normal(0, 1)` refit (matching the production prior) for G0's representative row (`grid_id=901`)
against the original production result already in `compiled_results.csv` for that same
`grid_id`. `log_M_mean`, `log_M_median`, `log_M_sd`, `log_M_q025`, `log_M_q975` all matched to
full floating-point precision (e.g. `log_M_mean = -0.95794097676536` both times) — a
byte-for-byte reproduction, confirming `prior_sensitivity.R` does reuse the grid row's own
`sim_seed` (same simulated dataset) and `fit_seed` (same sampler trajectory), not fresh
generator/sampler noise.

**Consequence for interpretation (this is the "case 2" scenario, in the terms the check was
framed in):** this specific replicate's own recorded bias is retrievable and meaningful:
`log_M_mean - (-1) = +0.042` (positive direction) for `grid_id=901` alone — consistent with the
figure showing that point sitting above the truth line. But `grid_id=901` is only 1 of 20
replicates for the (N=40, T=200, `d′=1.5`) condition; the **condition-level** bias (averaged
over all 20, in `g0_recovery_summary.csv`) is `-0.033` (negative direction) — the opposite sign.
Not a contradiction: per-fit posterior SD (~0.092) is much larger than this ±0.03-0.04 signal, so
individual replicates scatter around the small aggregate bias in both directions.

**Locked interpretation rule for the report:** the prior-sensitivity figure's *within-replicate*
comparison (same data held fixed, only the prior varies → the monotonic shrinkage-direction
pattern across `sd=0.5/1/2`) is valid and report-safe on its own. Its *absolute* position
relative to the truth line, for any single prior/replicate, must **not** be used to characterize
or contradict the aggregate 12-condition bias pattern — only the properly-averaged
`g0_recovery_summary.csv`/`g2_log_M_recovery.csv` tables may be cited for that claim. The report's
prior-sensitivity paragraph should state the shrinkage-direction conclusion only, not lean on the
figure's absolute bias-looking position as evidence about the aggregate bias's magnitude or
direction.

## 2026-09-25 — Day 5 midday: K=6 confidence-binning sensitivity analysis

- Implemented `code/03_recovery_analysis/sensitivity_binning.R`: reruns a small representative
  subset (G0: N=40/T=200/`d′=1.5`, 5 reps; G1: same design, all 3 `σ_c` levels, 5 reps/level —
  20 fits total, 1.4% of the full grid) at `K=6` instead of the production `K=4`, holding the
  underlying continuous evidence identical (same `sim_seed`) so only the discretisation
  granularity changes, and compares against the existing K=4 production results for the same
  `grid_id`s.
- **Found and fixed a real bug while implementing this** (protocol section 1.4's own reason for
  needing this check): `simulate_g0()`/`simulate_g2_gumbel()` never overrode
  `sim_metad_participant()`'s `r_z_c2_0`/`r_z_c2_1` correlation-matrix arguments, so they only
  worked at `K=4` by coincidence (hmetad's own hardcoded `diag(3)` default happened to match
  `K=4`'s 3 threshold gaps). `K=6` (5 gaps) immediately hit a `cov_matrix()` dimension-mismatch
  error on the very first fit — caught before any of the 20 fits' compute was wasted. Fixed by
  passing `r_z_c2_0 = r_z_c2_1 = diag(k - 1)` explicitly in both generators; verified `K=6` now
  works and `K=4` still recovers `M = exp(log_M)` exactly (regression check), full test suite
  re-run clean. Committed as its own fix (`c99333d`) before relaunching the 20-fit run.
- **Results:**
  - **G1 ordering accuracy is identical at K=4 and K=6: 100% (5/5 matched reps) both ways** —
    the primary RQ1 ordinal-recovery finding is not an artefact of the locked K=4 discretisation.
  - **G0 individual point-estimate differences are non-trivial**: up to 0.38 on the `log_M`
    scale between a cell's K=4 and K=6 fit (mean |diff| = 0.21 across the 5 reps), comparable to
    a single fit's own posterior SD (~0.09-0.1). However, **all 5/5 K=4/K=6 pairs have
    overlapping 95% credible intervals** — consistent with ordinary estimation noise from
    different discretisations of the same continuous data, not a detectable systematic
    K-dependent bias, though n=5 gives limited power to fully rule one out.
  - **Caught and fixed a second issue before it became misleading**: the script's first draft
    computed a data-driven `direction` flag correctly but paired it with a **hardcoded**
    `interpretation` string ("not materially sensitive") that didn't actually reflect the
    computed result (which showed sizeable individual-level shifts). Rewrote the interpretation
    text to be generated from the actual numbers (max/mean |diff|, CI-overlap count) rather than
    an assumption written before seeing the data — exactly the "no sensitivity analysis silently
    becomes the headline result" failure mode protocol section 5 warns against, caught here
    before it reached the report. Regenerated `robustness_table.csv` from the already-saved
    comparison data (no need to redo the 20 fits).
- Wrote `data/processed/sensitivity_binning_comparison.csv` (20 rows) and
  `data/processed/robustness_table.csv` (the one-page robustness summary).
- **Bottom line for the report:** the K=4 discretisation choice does not threaten the primary
  RQ1 conclusion (G1 ordering accuracy unchanged). G0's point-estimate sensitivity to bin count
  is present at the individual-fit level but not distinguishable from ordinary posterior
  uncertainty given the credible-interval overlap — reported honestly as "not conclusively
  resolved at n=5," not overclaimed as "no sensitivity" in either direction.

## 2026-09-25 — Day 5 morning: posterior predictive checks

- Implemented `code/04_ppc_and_comparison/ppc_joint_counts.R` for the 5 protocol-prespecified
  representative categories: G0 typical pass, G1 low-noise pass, G1 high-noise pass, G2 correct
  (Gumbel-min), G2 misspecified (Gaussian). **G1 "high-noise failure" does not exist to show** —
  all 720 G1 production fits passed (documented, not substituted with a cherry-picked worse
  fit). All 5 use the SAME representative condition (N=40, T=200, `d′=1.5`) already used for
  `prior_sensitivity.R`/`sensitivity_binning.R`, and all have `rep_id ≤ 2` so the full `brmsfit`
  is available without refitting.
- Unpacked `aggregate_metad()`'s `N` matrix into observed joint counts (reusing the column-layout
  verification already done for `compute_primary_metrics.R`) and used `hmetad::epred_draws_metad()`
  for posterior-predicted joint response probabilities, weighting each participant's predicted
  probability by their own stimulus-conditional trial count before pooling, so observed and
  predicted proportions are on the same basis (conditional on stimulus, summing to 1 over the 8
  response×confidence cells per stimulus).
- Fixed one bug on first run: `epred_draws_metad()` on the G2 "correct" (Gumbel-min) fit failed
  with `object 'gumbel_min_lcdf' not found` — `hmetad`'s `posterior_epred()` for a custom
  distribution looks up the R-side CDF functions by name in the calling environment, not just the
  compiled Stan model, so `code/01_simulate/simulate_g2_gumbel.R` (which defines
  `gumbel_min_lcdf`/`lccdf`) must be sourced even when no new Gumbel data is being simulated.
  Fixed by adding the `source()` call; reran clean.
- **Discrepancy results — all 5 fits show small overall PPC discrepancy** (max |discrepancy|
  0.004-0.013 across the 16 cells, RMSE 0.0024-0.0072): a static meta-d′ model fit at K=4 tracks
  the joint stimulus×response×confidence proportions closely for representative fits across
  every generator and both G2 variants — including the misspecified one.
- **Notable finding for the report's Discussion:** G2's misspecified (Gaussian) fit has both the
  largest *overall* discrepancy (RMSE 0.0072, ~3x the correctly-specified fit's 0.0038) **and** a
  distinctive *pattern* the correct fit doesn't show — its two largest single-cell discrepancies
  are both at the extreme (highest) confidence category (`S0R0C4`: −0.013; `S1R1C4`: +0.012),
  consistent with a genuine distributional-shape misfit concentrated in the tails (exactly where
  Gumbel-min and Gaussian differ most). This nuances the LOO/ELPD result from `loo_comparison.R`:
  **raw PPC discrepancy on its own is a fairly insensitive detector of this particular
  misspecification** (all 5 fits "look fine" by max/mean discrepancy alone), but LOO reliably
  distinguishes the models, and PPC's per-cell *pattern* (not just its magnitude) still carries
  the signal if inspected specifically at the confidence extremes. Directly actionable for
  protocol section 6.2's interpretation template: ordinal/point-estimate agreement (or, here,
  superficially small PPC discrepancy) does not by itself establish generative adequacy —
  corroborating diagnostics (LOO; cell-level PPC pattern, not just aggregate magnitude) matter.
- Wrote `data/processed/ppc_joint_counts.csv` (80 rows: 5 fits × 16 cells),
  `data/processed/ppc_discrepancy_summary.csv`, `outputs/figures/ppc_scatter.png`, and
  `outputs/figures/ppc_discrepancy.png`.

## 2026-09-25 — Day 6 (start): five headline figures, and a PPC wording correction

- Implemented all five `code/05_figures/fig_*.R` scripts (colour-blind-safe Okabe-Ito palette;
  every replication shown as a raw point; failed fits kept and marked `x`, never dropped; N, T,
  fit counts and replication counts stated in subtitle/caption; each caption names generator,
  fitted model, estimand and uncertainty display): `fig_1_design` (schematic, numbers read from
  `design.yml`/`grid.csv` so it cannot drift from what was run), `fig_2_g0_validation`
  (per-replicate error + per-condition coverage with Wilson CIs and pooled coverage),
  `fig_3_g1_ordinal_recovery` (the RQ1 headline: all 720 points, log_M falling with σ_c in every
  N×T panel), `fig_4_g2_misspecification` (paired ELPD + per-replicate log_M error by variant,
  Pareto-k caveat in the caption), `fig_5_ppc`.
- Layout defects found by actually looking at the rendered PNGs and fixed before committing:
  fig 1's fitted-model text overflowed its box; fig 2's subtitle was clipped and its pooled-
  coverage label overlapped data. (Fig 3/4/5 rendered cleanly.)
- **Correction to the 2026-09-25 PPC entry above.** That entry (and an earlier draft of fig 5's
  subtitle) described the misspecified G2 fit's extreme-confidence discrepancy pattern without
  stating it comes from **one replicate per fit** (rep 1 of each representative condition). Checked
  directly against `ppc_joint_counts.csv`: in that replicate the misspecified fit's four largest
  |discrepancies| are all at confidence level 4 (−0.0133, +0.0119, +0.0118, −0.0105), whereas
  the other fits' largest are spread over levels 1-3 (G2 correct: levels 1,1,4,4). That is a
  real observation but **n = 1 per fit, so it is suggestive, not established** — fig 5's subtitle
  now says so, and the report must not present it as a demonstrated tail-misfit mechanism. The
  LOO result (240 paired datasets) remains the well-powered evidence for misspecification
  detection; a proper test of the C4 pattern would need the PPC summary computed across many G2
  replicates (the per-fit `epred_summary` is already saved for all 480 G2 rows, so this is cheap
  and is the natural follow-up if time allows).
- Not yet done: README rewrite, `manuscript/report.md`, `diagnostics_summary.R`, CITATION/tag.

## 2026-09-25 — Day 6: diagnostics summary (RQ3 material)

- Implemented `code/04_ppc_and_comparison/diagnostics_summary.R` →
  `data/processed/diagnostics_overall.csv` (by generator/variant) and `diagnostics_by_cell.csv`.
  Stated in the script and here: all diagnostics/`elapsed_secs` describe each row's **final
  attempt only**; escalated rows' first-attempt diagnostics and time were not retained, so
  elapsed time understates compute for the ~11% of rows that were escalated.
- **Convergence failures are rare and structured.** Failure rate: G0 0.4% (1/240), G1 0.0%
  (0/720), G2-correct 0.8% (2/240), G2-misspecified 0.0% (0/240); 0 `error` rows anywhere.
  All 3 fails sit at d′=0.75 (G0 N=40/T=400; G2-correct at T=100 for both N=20 and N=40). Both
  G2-correct fails were divergence-driven (2 divergences in total); no fit in the whole grid hit
  max treedepth; worst final-attempt R-hat 1.012, worst min bulk/tail ESS 620/408.
  (Refines the earlier tally: the 2 G2 fails are both in the *correct* Gumbel-min variant.)
- **Escalation (a softer difficulty signal) is far more patterned than failure:** overall 7.5–12.5%
  by variant, but up to 55% in low-information / high-noise cells (G0 N=20/T=100/d′=0.75; G1
  σ_c=high at d′=0.75, T=100/200, and at N=20/T=100/d′=1.5). Sampler difficulty therefore tracks
  low d′, short T and high readout noise — the regime where the meta-d′ likelihood is least
  informative — rather than being random.
- Remaining: README rewrite, `manuscript/report.md`, CITATION/release tag.

## 2026-09-25 — Correction: a bias range in the prior-sensitivity entry was misattributed

While drafting the report I re-derived every cited number from `data/processed/*.csv`. The
2026-09-24 prior-sensitivity entry says the negative aggregate bias across "G0's 12 conditions"
ranges "−0.007 to −0.092 per condition". That range belongs to the **G2 correctly-specified**
fit (`g2_log_M_recovery.csv`). The verified figures are:

| Fit | log_M bias range across 12 conditions | Negative in | RMSE range |
|---|---|---|---|
| G0 (`g0_recovery_summary.csv`) | −0.177 to −0.025 | 12/12 | 0.069–0.326 |
| G2 correct (Gumbel-min) | −0.092 to −0.007 | 12/12 | 0.042–0.272 |
| G2 misspecified (Gaussian) | +0.064 to +0.195 | 0/12 | 0.105–0.299 |

Nothing else in that entry depends on the wrong range (the shrinkage-direction conclusion, the
identifiability discussion and the "open question" framing are unchanged), and G0's true bias is
if anything *larger* than the number quoted, so the "small but consistently negative" description
still holds. Recording it here rather than editing the earlier entry, to keep the audit trail.
The report uses the verified table above.
