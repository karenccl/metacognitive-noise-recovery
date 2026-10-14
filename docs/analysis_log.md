# Analysis Log

Time-stamped log of launched batches, failures, reruns, and deviations from the locked design.

## 2026-09-22

- Scaffolded repository structure per the design (`code/`, `config/`, `data/`,
  `outputs/`, `docs/`, `tests/`, `manuscript/`, plus `README.md`, `LICENSE`, `CITATION.cff`,
  `.gitignore`, `Makefile`). No simulation or fitting code implemented yet.
- Committed (`869d5e8`) and pushed scaffold to `origin/main`
  (https://github.com/karenccl/metacognitive-noise-recovery).

## 2026-09-23 — Day 0: verify backend

- Confirmed R 4.5.0 installed at `C:\Program Files\R\R-4.5.0`.
- `cmdstanr::cmdstan_version()` returned `2.36.0`, matching the pinned version. CmdStan path: `~/.cmdstan/cmdstan-2.36.0`.
- Ran a CmdStan compile+sample smoke test using the bundled
  `examples/bernoulli/bernoulli.stan` model (2 chains, 200 warmup / 200 sampling draws each,
  seed 12345). Compiled and sampled without error in ~1.2s; `rhat` ≈ 1.03 for `theta` and
  `lp__`, no divergences. Backend verified working end-to-end.
- Checked availability of all packages in the initial package list: `cmdstanr`, `brms`,
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
- **Deviation from the initial package list:** use `qs2::qs_save()` / `qs2::qs_read()` in place of
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
  `.gitignore` exclude it), consistent with the design.
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
  evidence" mistake named in the design.
- Wrote the DDM-to-empirical-d′ calibration plan (bisection on drift `v` at fixed `a`/`t0`,
  targeting `d′ ∈ {0.75, 1.5}` within ±0.02, output to
  `outputs/tables/ddm_calibration.csv`) and the σ_c low/medium/high pilot plan. Flagged
  explicitly that raw confidence-category occupancy is **not** a valid degeneracy diagnostic
  here, since the locked rank-based within-subject `K=4` discretisation guarantees ~25% per
  category by construction regardless of σ_c (docs/design_decisions.md) — the pilot instead checks
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
- Wrote the design's required unit tests into `tests/test_discretise_confidence.R` (12 tests:
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
  correctness check, run manually and logged here, per the design's own Day 2 morning wording
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
  single illustrative run per the design's own caution not to overinterpret one fit. Saved
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
- **Consulted the project lead** on replication count vs. compute time, given this is a genuine
  resource/timeline tradeoff with real Monte Carlo precision consequences (the design explicitly
  allows dropping to 20 or 15 reps). Chose: keep 30 reps/cell, add concurrent batch dispatch
  instead of reducing precision.
- Implemented `code/00_setup/02_create_grid.R`: builds `config/grid.csv` with `grid_id`,
  `cell_id` (shared between a G2 cell's two fit-variant rows so they use the *same* simulated
  dataset, per the design's "two fits per generated dataset"), deterministic
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
- **Smoke-tested the full batch pipeline twice** (the design's Day-2 gate): once sequentially
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
- **Pre-specified the failed-fit handling rule** in `docs/design_decisions.md`, before any
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
- Per the pre-specified failed-fit rule (above): the 3 `fail` rows stay in the primary analysis,
  flagged; a pass-only sensitivity analysis will check whether they change any conclusion. Zero
  `error` rows means there is nothing to fold into the RQ3 convergence-failure tabulation beyond
  these 3 flagged fits (a very low failure rate at N≥20, consistent with the G0 baseline's clean
  behavior on Day 2).
- Confirmed 0 lingering R processes after completion (clean shutdown, no orphaned workers).
- **Not yet done:** compiling/aggregating the 1440 individual `data/interim/*.qs2` result files
  into the compact processed products in `data/processed/` (the design's Day 3 morning task,
  `code/03_recovery_analysis/compile_results.R`, not yet implemented) — that is the next step
  before any recovery metrics, figures, or the report can be produced.

## 2026-09-24 — Day 3 morning: compile_results.R and G0 recovery summary

- Implemented `code/03_recovery_analysis/compile_results.R`: reads every `data/interim/*.qs2`
  file, extracts a compact per-row summary (grid metadata, status/diagnostics, and a `log_M`
  posterior point summary — mean/median/sd/95% CI — from the compact `draws_b_sd$b_Intercept`
  saved by `run_one_cell.R`), cross-checks the result set against `config/grid.csv` for
  completeness (missing/duplicate/unexpected `grid_id`s — from structured status fields, not
  file presence alone, per the design), and computes G0 bias/RMSE/coverage/interval-width
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
    the pre-specified rule anticipated turned out not to matter for G1.
- Confidence-category marginals confirmed ~25%/category as expected by construction (not a
  degeneracy diagnostic, per the Day-1 design decision); per-replicate tie/cut-point diagnostics
  were not persisted in the compact output format and were not re-audited here (documented
  limitation, validated instead at the Day-1 pilot stage).
- Wrote `data/processed/g1_failure_rates.csv`, `g1_empirical_dprime_check.csv`,
  `g1_primary_metrics.csv`, `g1_sensitivity_metrics.csv`.
- **Bottom line for the report's Results section:** under the specified DDM-type generator,
  estimated static `log_M` declined monotonically as confidence-readout noise increased, with
  near-perfect ordinal recovery — consistent with (but not yet cross-checked against) adequate
  generative fit; that check is the Day 5 PPC task, still pending. Per the design's
  interpretation template, the ordinal-recovery claim alone does **not** yet establish that the
  fitted static meta-d′ model is a generatively adequate account of the full response-confidence
  distribution. G1's `run_one_cell.R` records don't carry PPC precursors (only G2 rows compute
  `loo`/`epred_summary`, per the 2026-09-23 output-format decision) — G1's own posterior
  predictive check (the design's "G1 low-noise pass" / "G1 high-noise pass/failure" representative
  fits) is a Day 5 task requiring a fresh `epred_draws_metad()` call on a handful of saved fits,
  not yet done.

## 2026-09-24 — Day 4: G2 LOO/ELPD comparison

- Implemented `code/04_ppc_and_comparison/loo_comparison.R`. Verified before trusting it at
  scale: `loo::loo_compare()` on one manually-loaded correct/misspecified pair worked correctly,
  and `dim(loo_object$pointwise) = [20, 5]` for an N=20 fit confirms (again) that one LOO
  observation is one participant's aggregated count vector (5 = the standard `pointwise` columns
  `elpd_loo`/`mcse_elpd_loo`/`p_loo`/`looic`/`influence_pareto_k`, 20 = participants) — stated
  explicitly in the script's own header per the design's requirement to document the LOO unit
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
- **Bottom line for the report:** G2 supports the design's misspecification-sensitivity
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
  three prior widths. Per the design's instruction to treat this as an identifiability finding,
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
  small-magnitude, 12-condition-consistent aggregate effect — the design's own caution against
  overinterpreting one illustrative run applies here too): the residual small negative bias's
  ultimate source (candidates include posterior-mean-of-a-nonlinear-log-link-transform effects,
  or hierarchical partial-pooling behavior on the `sd_participant` components) is left as a
  documented open question / limitation for the final report, not chased further within the
  remaining project timeline.
- Wrote `data/processed/prior_sensitivity_summary.csv` and `outputs/figures/prior_sensitivity.png`
  (violin + posterior median/95% CI by prior, faceted by generator, with the G0 truth line shown
  only on the G0 facet since G1 has no single true `log_M` by construction).

## 2026-09-25 — Verification: prior_sensitivity.R reuses the exact original grid data/fit

Checked whether `prior_sensitivity.R`'s two "representative rows" are
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
- **Found and fixed a real bug while implementing this** (the design's own reason for
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
    becomes the headline result" failure mode the design warns against, caught here
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

- Implemented `code/04_ppc_and_comparison/ppc_joint_counts.R` for the 5 pre-specified
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
  the design's interpretation template: ordinal/point-estimate agreement (or, here,
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

While drafting the report, every cited number was re-derived from `data/processed/*.csv`. The
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

## 2026-09-25 — Day 6: report, README, Makefile

- Wrote `manuscript/report.md` (structured abstract, methods, results, discussion, limitations,
  reproducibility statement) and `manuscript/references.bib` (six methods references plus the
  `hmetad` package). **Every number in the report was re-derived from `data/processed/*.csv`**
  (`report_numbers.R` scratch check), which is what exposed the misattributed bias range
  corrected above. A line-by-line check of the draft against the data then caught and fixed
  three statements before commit: an incorrect "least informative cell" for the G0 maximum RMSE
  (0.326 is N=20/T=200, and RMSE is not strictly monotone in T at d′=0.75), a "rules out" claim
  about prior shrinkage that a single-replicate sweep cannot support (now "argues against"), and a
  "no between-participant variability" statement that ignored the small threshold spread in the
  G0/G2 generators.
- Rewrote `README.md` (question, design, headline results, repo map, install, reproduction,
  failure policy). It states plainly what regenerates from tracked files alone (the figures —
  verified with `git ls-files` that every figure input is tracked) versus what needs the
  git-ignored `data/interim/` grid output (compile/primary-metrics/LOO/PPC scripts).
- Makefile: `all` now follows the production order (G1, G0, G2) and includes a new `analyse`
  target; the two long refit-based checks are in a separate `robustness` target (kept out of
  `all`). **`make` is not installed on this machine, so the Makefile was not syntax-checked or
  run** — the recipes are the same `Rscript` commands that were run by hand.
- `CITATION.cff` repository URL set to the real remote. Unit tests re-run: all pass.
- **References are unverified**: entered from memory; the `.bib` and README both say to check
  them before release. The `hmetad` entry has no author list (not established from the package).
- **Not done:** release tag and public release (not created), `manuscript/supplementary_methods.md` (still a stub), a pasted
  `sessioninfo` in `docs/computational_environment.md`, CV bullet/plain-language summary, and the
  optional JAGS and open-data checks (reported as limitations, per the design's stop rule).

## 2026-09-25 — Day 6: supplementary methods, environment record, and two corrections

- Wrote `manuscript/supplementary_methods.md` (S1–S13: sampler, G1 equations, calibration,
  generators, discretisation, model, diagnostics, seeds/grid, metric definitions, robustness
  checks, storage, design deviations, errata) and replaced `docs/computational_environment.md`
  with real session info, hardware (Core Ultra 7 155H, 16 cores/22 threads, 31.4 GB) and the
  package/backend table. Details were taken from code, config and CSVs, not memory.
- **Correction 1 — the sampler was `rstan`, not CmdStan.** The session-info capture showed
  `getOption("brms.backend")` is `NULL`. Reading `fit$backend` from saved production fits
  (grid_ids 901, 561, 1321) confirmed `rstan` (`stanfit`; rstan/StanHeaders 2.36.0.9000).
  `options(brms.backend = "cmdstanr")` was only ever in a commented-out line
  (`code/00_setup/00_packages.R`) and in the README, so `brms` used its default. The Day-0
  "backend verified" entry above tested `cmdstanr` directly on a bundled example and never
  exercised the `brms` path. (The PSOCK worker processes loading `rstan` that were noticed during the
  first chain-parallel benchmark were this evidence, and it was not followed up then.) Same Stan
  version and model, so the statistical results are not in question, but draws are not
  bit-identical across backends. Fixed in the environment doc, README (install section), report
  §3.1, supplement S1, the Makefile comment and the `00_packages.R` comment. **Not done:** pinning
  `backend = "rstan"` inside `fit_one_hmetad()`; that would change fitting code after the results
  were generated, so it is left as a recommendation.
- **Correction 2 — calibration table in `design_decisions.md`.** Its hit-rate, false-alarm-rate and
  mean-RT cells (0.702/0.298, 0.836/0.164, ~1.1 s, ~0.75 s) and "d′ = 1.500" had been entered
  without the CSV in view. From `ddm_calibration.csv`: hit/FA 0.644/0.358 and 0.771/0.226; mean RT
  0.875 s and 0.827 s; empirical d′ 0.7332 and 1.4954 (errors 0.017 and 0.005, both inside ±0.02).
  The "agree exactly" claim is now "agree to within 0.0001". Corrected in place, with a note, and
  in the `design.yml` comment; the earlier "1.500" in the 2026-09-23 log entry is left as written
  and superseded by this note. The σ_c pilot figures quoted in the same section were re-checked
  against `sigma_c_pilot.csv` and are right.
- **Also verified while writing:** the Gumbel-min mean/variance check. A ±4 integration grid gave
  variance 0.92–0.96 (left-tail truncation); on a ±20 grid the mean equals μ and the variance is
  1.0000, so the earlier "≈1" was right for the reason the design claims. And stated the
  50,000-step non-decision guard honestly as un-audited rather than "not observed".
- Still open: release tag, CV bullet and plain-language summary, verifying `references.bib`, optional JAGS and open-data checks.

## 2026-09-28 — Correction: the G0 half of the K=6 check was not a re-binning

- The 2026-09-25 entry above (and the report, README and supplement) said K=6 kept "the
  underlying continuous evidence identical (same `sim_seed`) so only the discretisation
  granularity changes". That is true for **G1** (continuous `y` is generated first and binned
  afterwards; verified identical `y` and responses at K=4 vs K=6) but **false for G0**:
  `simulate_g0()` draws discrete confidence directly from hmetad's generative model, so K=6
  is a different model and random stream. With the same seed, only the stimulus sequence is
  shared; in the checked cell (`sim_seed` 20261824) responses agree on 95.1% of trials, mean
  accuracy differs (0.7706 vs 0.7725), and the K=6 x K=4 confidence table is not block-structured.
- Consequence: the G0 K=4/K=6 differences (mean |diff| 0.21, max 0.38) confound binning with a
  different dataset and are NOT evidence about bin-count sensitivity. The earlier statement that
  they were "consistent with ordinary estimation noise from different discretisations of the same
  continuous data" is withdrawn. Sensitivity of G0 to bin count is untested.
- Valid evidence stays as before, and is unaffected: G1 ordering accuracy 100% (5/5) at both K;
  G1 mean |diff| 0.027, max 0.099, 15/15 intervals overlap.
- Rewrote `sensitivity_binning.R`: header states the distinction; it reuses the saved comparison
  by default (`--refit` redoes the 20 fits); adds `valid_rebinning`; the G0 row is labelled
  "NOT a re-binning"; the G1 interpretation text is generated from the data (an inline "posterior
  SD ~0.07-0.09" drafted here was wrong, actual K=4 interval half-widths are 0.08-0.51, and was
  replaced). Regenerated `robustness_table.csv` and `sensitivity_binning_comparison.csv` without refitting.
- Report (Methods, Results, Limitations vi), README and supplement S10 corrected accordingly.

## 2026-09-28 — Post-hoc diagnostics: bias, G2 coverage, nuisance recovery (no refitting)

- Added `code/03_recovery_analysis/bias_diagnostics.R` (in `make analyse`); reads the 720 G0/G2
  compact draws. Exploratory, added after the results were seen; report section 4.7 says so.
- (11) Bias, posterior mean/median: G0 -0.075/-0.056, G2-correct -0.044/-0.035, G2-misspecified
  +0.132/+0.144. Negative in 66% of G0 and G2-correct fits; shrinks with N and T. Signed error vs the
  fit's posterior between-participant SD of log_M (true SD = 0): Pearson -0.48 (G0), -0.33 (G2-correct),
  -0.21 (misspecified); median within-cell -0.54/-0.33/-0.41. Interpretation kept modest: consistent
  with a prior/hierarchy effect, cause not tested (no alternative SD prior was fit).
- (12) G2 coverage of true log_M: correct 233/240 = 97.1% (Wilson 94.1-98.6), misspecified 195/240 =
  81.2% (75.8-85.7); worst cell N40/T400/d0.75 = 45%. Per-cell tables in `g2_coverage.csv`.
- (13) Correct fit: d' bias 0.001 (RMSE 0.039), c bias -0.002 (0.020). Misspecified: d' +0.073 (cov 51%),
  c -0.113 (cov 7%), gap +0.077 (cov 0.4%). Gumbel and Gaussian latent scales differ, so the
  misspecified rows measure compensation, not estimation error. Gap intercepts: assumed truth -1
  (= mean_z_c2) was covered only 87-88% even under G0/correct, so the assumption about the gap
  parameterisation is unverified and those rows are descriptive.
- Outputs: bias_fit_level.csv, bias_diagnosis_summary.csv, bias_by_sample_size.csv, g2_coverage.csv,
  g2_nuisance_recovery.csv. Report Limitation (iv) reworded from "unexplained" to "partly characterised".

## 2026-09-28 — G1 summary, point estimate, R-hat boundary, Gumbel CDF

- **G1 summary.** `compute_primary_metrics.R` no longer fits a linear slope of `log_M` on
  sigma_c or reports its p-values: the three calibrated levels are not equally spaced on any
  natural scale, and p-values on simulation replicates reflect only the replication count. It now
  reports, per N x T x d' cell, per-level means, SDs and MC SEs, adjacent and low-high differences
  with independent-sample MC SEs, Spearman, ordering accuracy and separation probabilities.
  Result unchanged in substance: means ordered low > medium > high in 12/12 cells (mean `log_M`
  -0.30..-0.18 / -0.84..-0.66 / -1.93..-1.71; differences 0.46-0.57 and 0.88-1.20; smallest
  adjacent gap 7.2 MC SEs). Report abstract, RQ1 prediction, methods, results and README reworded;
  the RQ1 prediction text was changed after seeing the data (it named the slope), which is noted here.
- **Point estimate.** G0/G2 bias and RMSE used the posterior mean while G1 used the median.
  G1 now uses the posterior mean; the median version is kept as a sensitivity
  (`g1_primary_metrics_median.csv`): ordering accuracy 0.95-1.00 and 12/12 direction check both ways.
  Fig 3 now plots posterior means; its subtitle no longer clips and the empty fail/error legend
  entries are gone.
- **R-hat boundary.** `extract_fit_summary.R` now flags `max_rhat > rhat_max` instead of `>=`.
  Fits with max R-hat exactly 1.01: 0 of 1,440, so no fit would be reclassified and nothing was refit.
  (One fit has max R-hat 1.0124 and was already flagged.)
- **Gumbel CDF.** R-side `gumbel_min_lcdf` now uses `log(-expm1(-exp(z)))`, which keeps
  precision when exp(z) is small. The Stan twin already used `log1m_exp`, so no fit is affected;
  the stored G2 `epred_summary` objects were computed with the old R form and were not regenerated
  (differences would arise only in extreme lower tails).
- 54 tests pass; Fig 1 and Fig 3 regenerated.

## 2026-09-28 — Priors record, Fig 4 coverage, config, docs, figure polish

- **Default priors.** New `prior_summary.R` reads `prior_summary()` from stored fits (G0, G2
  correct, G2 misspecified; identical priors) into `outputs/tables/prior_summary.csv`. Finding not
  previously stated anywhere: only `log_M` and the threshold-gap intercepts had priors we set
  (`normal(0,1)`); the d' and criterion intercepts are flat (improper) and every participant-level SD
  is `student_t(3, 0, 2.5)`. Added to the report (§3.3) and supplement. Nothing refit; the wide
  default SD prior is named as an untested candidate for the small negative bias.
- **Fig 4 coverage.** Fig 4 gets panel C: per-condition coverage of true `log_M` with Wilson intervals, from
  `g2_coverage.csv` (so `bias_diagnostics.R` must run first; it does in `make analyse`).
- **Setup and Makefile.** `make analyse` now also runs `bias_diagnostics.R` and `prior_summary.R`.
  `00_packages.R` checks required packages (no installation; use `renv::restore()`), and
  `01_config.R` validates `design.yml`, so `make setup` does real work. Both were run.
- **Ground truth in config.** Generating truths moved into `config/design.yml` (`truth:` block: log_M, c, mean_z_c2);
  the eight scripts that hard-coded -1 now read it. Values are unchanged, so no results changed.
  (The generator function defaults still carry `mean_z_c2 = -1`; run_one_cell passes log_M from config.)
- **Design-decisions document.** `design_decisions.md` now marks the
  original "all fits use `aggregate = TRUE`" decision as superseded by the explicit-aggregation wrapper.
- **Fig 1 wording.** Fig 1 now says confidence-threshold gaps are pooled, matching `hierarchical_thresholds: false`.
- **Figure polish.** Fig 2 subtitle grammar; Fig 3 legend (done earlier); Fig 5 title no longer claims all fits
  "track the joint counts closely" (now: discrepancies are small for every fit, including the misspecified one).
- The README compute-time note was already present.

## 2026-09-28 — Framing, checklist, clone check

- Report and README reframed: RQ1 is a validity check (readout noise removes information, so a working
  model should register it); RQ2 (misspecification visible to LOO and in `log_M`, not in aggregate PPC)
  is presented as the main finding. Abstract conclusion, RQ labels and Discussion ("Framing" paragraph)
  changed after seeing all results; noted here rather than presented as pre-planned.
- Limitations extended: unvaried brms default priors (xi); one seed base/environment/backend (xii);
  next steps now include varying the SD prior. Reproducibility statement lists all corrected errors.
- Added `docs/deliverables_checklist.md` (with open items: reference check, full-pipeline reproduction,
  tag, archive) and `docs/summaries.md` (CV line, ~100-word summary, caveats).
- Fresh-clone check: a clean `git clone` rebuilds all five figures from tracked files alone. It exposed
  that figs 2-4 used unseeded jitter, so reruns changed the PNG bytes; `set.seed(20260923)` added and
  two consecutive runs now produce identical files. The full pipeline (renv::restore, fits) was not
  re-run from a clone.
- Not done: release tag (not created), Zenodo/OSF archive (optional), verification of
  `references.bib`.

## 2026-09-28 - References verified

- Checked all six published references in `references.bib` against Crossref by DOI: authors, title,
  journal, volume, issue, pages and year all matched the from-memory entries. Corrections/additions:
  DOIs added to all; Vehtari et al. issue number (5) was missing; the `hmetad` entry was a placeholder
  and is now filled from `citation("hmetad")` (O'Neill & Fleming, 2026, version 0.2.1; key renamed
  `hmetad2026`) and cited in the report.
- A title search for Pleskac & Busemeyer first returned the 2011 erratum (Psychol. Rev. 118, 56), not
  the article; the entry was verified by DOI (10.1037/a0019737) and is the original 2010 article.
- Not confirmed from a source: the Buerkner (2017) page range 1-28 (Crossref returns no pages for JSS).
- Only bibliographic metadata was checked. The papers were not re-read to confirm that each supports the
  sentence citing it in the report.

## 2026-09-28 — Release checks

- **Environment.** `renv::status()` was flagging a dependency-scan error on `data/interim/` (1,441 files)
  and unused recorded packages. Added `.renvignore` (data/, outputs/, manuscript/, docs/) and re-snapshotted:
  the lockfile drops 62 unused packages (167 to 105; every required package remains) and now records the
  metacoglab and stan-dev r-universe repositories, which `hmetad` and `rstan` need for `renv::restore()`.
  Status: consistent.
- **Downstream rerun.** New `code/run_downstream.R` (portable stand-in for `make`) reran compile, G1 metrics,
  LOO, diagnostics, PPC, bias diagnostics, prior summary and all figures from `data/interim/`, then the
  tests (54 pass). Every table was byte-identical to the committed version except the two PPC tables, which
  differ only at the 1e-16 level for G2-correct (from the `expm1` form of the Gumbel CDF adopted earlier).
  Those two files were refreshed. Fig 4's PNG varies byte-for-byte between runs even with fixed seeds
  (device-level; its input tables are identical), so PNG byte-identity is not guaranteed for that figure.
- **Editorial edits.** A batch rewording (protocol references, "pre-registered" to "pre-specified", CmdStan
  path) was reviewed and applied. Two defects in it were fixed: a truncated last line in `fig_5_ppc.R`
  (a parse error) and the removal of `LICENSE`/`license: MIT`; MIT was kept.
- **Single-fit determinism (completed later the same day).** Grid cell 721 (G0, N = 20, T = 100, d' = 0.75,
  rep 1) was refitted from scratch with `run_one_cell.R` (2.9 min, fit seed 21261644). Posterior draws of the
  population effects and SDs were exactly identical to the stored ones (max absolute difference 0), as were
  the aggregated counts, max R-hat (1.00206), status and escalation flag. This is one fit on one machine with
  the same package versions; it does not establish bit-identity across machines or backends. The original
  result file was restored byte-for-byte afterwards.
- **Not done.** Full-pipeline reproduction from a clone (`renv::restore()` plus the grid) has not been run.

## 2026-09-28 - v1.0.1

- Local and remote `main` had diverged. The local licence-removal commit was dropped (MIT kept); its
  remaining wording edits were already upstream. A leftover analysis-log wording commit was kept.
- `report.md`: two clarifications, with no change to any result. The G2 Gaussian fit's `log_M` "bias" is
  deviation from the Gumbel-min generating value, not recovery of a Gaussian parameter. One LOO
  observation is one participant's aggregated count vector.
- `CITATION.cff` version 1.0.1. Tagged `v1.0.1`; `v1.0.0` left where it was.

## 2026-09-28 - v2 extension 1: PPC on all 480 G2 fits (result)

Design locked in `3cc7e71` and `01d1b9c` (`design_decisions.md`, "v2 extension 1"). Script
`code/04_ppc_and_comparison/g2_ppc_all.R`; outputs in `data/processed/v2/` and
`outputs/figures/v2/fig_g2_ppc_all.png`. No refitting.

- **Runs.** First run stopped inside the helper that builds participant x cell counts (a `tibble()`
  data-mask bug) before any statistic was computed; fixed and rerun. The figure subtitles were then
  wrapped (layout only) and the script rerun; `g2_ppc_summary.csv` was byte-identical.
- **Check before use.** Statistic 1 for grid 1321/1322 reproduced `ppc_discrepancy_summary.csv`
  (max abs diff 1.1e-17).
- **Inclusion.** 480/480 fits have `epred_summary`; 478 pass, 2 fail; 240 pairs.
- **Paired.** Misspecified worse in 96.7% (stat 1), 95.8% (stat 2), 94.6% (stat 3) of pairs. Median
  ratio misspecified / correct: 2.64 (stat 1; 90% range 1.09-7.88), 6.82 (stat 2), 1.09 (stat 3).
  Descriptively, median stat 1 was 0.0031 (correct) vs 0.0086 (misspecified): small in absolute
  terms, but systematic.
- **Oracle-calibrated detection.** Pooled (mean of 12 cells): stat 1 0.875, stat 2 0.933, stat 3 0.487.
  Stat 1 detection was >= LOO's > 2 SE rate in all 12 cells (0 of 12 below). Lowest cell: N = 20,
  T = 100, d' = 0.75 (stat 1 0.15, LOO 0.10). Stat 3 single pooled threshold (secondary): 0.30.
  Expected counts < 5: median 14.7% of participant x cell entries (range 0-50%).
- **Verdict (pre-specified rule): Reversed** (pooled stat 1 detection 0.875 >= 0.8). Pass-only
  sensitivity: also Reversed (stat 1 0.874). Per the rule, the v1 claim "aggregate PPC does not
  reveal the misspecification" is withdrawn, and the rule's wording that the v1 replicate was
  unrepresentative is not followed, because its ratio (1.9) lies within the observed range; what
  failed was reading "small in absolute terms" as "not revealed". Logged as a dated deviation in
  `docs/design_decisions.md` (v2 extension 1).
- **Predictions.** P1 not supported (proportion worse 96.7% > 50% held, but median ratio 2.64 > 1.5).
  P2 not supported as worded (paired proportion 95.8% vs 96.7%), although stat 2 had the larger
  ratio and higher detection. P3 not supported (stat 1 detection is not below LOO in any cell); the
  rise with T and N held.
- **Caveat that stays.** Detection uses an oracle threshold from the correct model's own
  distribution, which an analyst would not have. A low rate would have been an upper bound; a high
  rate says the discrepancy is systematic and detectable given a reference, not that an analyst
  eyeballing absolute RMSE ~0.009 would notice it. Participant-level X2 (stat 3), which is scaled by
  sampling noise, detected it far less often (0.49).
- **Not yet done.** `manuscript/report.md` not changed; revision planned for v1.1.

## 2026-09-28 - v1.1.0 release preparation

- Report revised (`e7f0511`): §3.5 methods, §4.4 results (Fig. 6), abstract, discussion,
  limitations (vi), next steps and reproducibility statement now carry the reversed PPC conclusion.
- `fig_5_ppc.R`: title no longer says discrepancies are small "including the misspecified one";
  subtitle and caption point to the all-G2 result (Fig. 6). Figure regenerated.
- README status, headline and limitation bullets, repository map; supplement S9 (PPC method) and
  S13 errata 5-6 updated. Makefile `analyse` target now also runs `g2_ppc_all.R`.
- `CITATION.cff` version 1.1.0.

## 2026-09-29 — Commit messages rewritten

- Removed attribution trailers from the messages of the commits after `9f3fb50`. File contents are
  unchanged, but every later commit hash changed (tags `v1.0.1` and `v1.1.0` moved with them).
  Hash references in this log, `design_decisions.md` and `g2_ppc_all.R` were updated:
  `4785b35` → `3cc7e71`, `37bed3d` → `01d1b9c`, `4faac0e` → `e7f0511`. Commit dates, and so the
  order "design before analysis", are preserved.

## 2026-09-29 - v2 extension 2: replicated-data posterior predictive p-values (result)

Design locked in `32de75f` (`design_decisions.md`, "v2 extension 2"). Script
`code/04_ppc_and_comparison/g2_ppp_fullfits.R`; outputs `data/processed/v2/g2_ppp_by_fit.csv`,
`g2_ppp_summary.csv`, `outputs/figures/v2/fig_g2_ppp.png`. No refitting.

- **Preconditions.** All 48 files have a `brmsfit`; per-draw probabilities sum to 1 (max deviation
  5.6e-16); draw means reproduce the stored `epred_mean` (max deviation 5.6e-17). 4,000 draws per fit.
- **Runs.** One full run gave the results below. The panel B subtitle was clipped and count labels
  overlapped the error bars, so the plotting code was changed (layout only) and the script rerun;
  both CSVs were byte-identical (seeded per fit: `seed_base + grid_id`).
- **Inclusion.** All 48 fits passed diagnostics (the two failed G2-correct fits are replications > 2),
  so the pass-only sensitivity is identical to the primary analysis. The script applies the rule's
  count thresholds as proportions for a smaller pass-only set; this was not needed.
- **Flags (p < 0.05), out of 24 per family.** Stat 1 (aggregate RMSE): Gaussian 16 (Wilson
  0.47-0.82), correct 0. Stat 2 (highest confidence): Gaussian 20, correct 0. Stat 3 (participant
  X2/df): Gaussian 15, correct 9. On the same 24 datasets: oracle stat 1 (extension 1) 22, LOO > 2 SE
  16. Stat 1 by T: 2/8, 7/8, 7/8 at T = 100/200/400; by N: 6/12 and 10/12. Median p (stat 1):
  correct 0.52, Gaussian 0.010.
- **Verdict (pre-specified rule): Partial** (16/24 is between 7 and 17; correct 0/24). Stat 2 meets
  the naming condition (20/24 flagged, 0/24 false alarms), so the report names it as a targeted
  check that did flag the misspecification.
- **Predictions.** P1 held for stats 1 and 2 (0/24) but not stat 3 (9/24). P2 held (16/24 practical
  vs 22/24 oracle). P3 not supported: detection appears from T = 200, not only at T = 400.
- **Exploratory (not tested).** Stat 3 flags the *correct* family often (6/8 at T = 400, 7/12 at
  N = 40), so it is not a usable check here. One candidate explanation is a participant-level misfit
  shared by both families: simulated participants' confidence thresholds vary slightly, but the
  fitted models pool them (report §5, limitation iii). The aggregate statistics average this out.
- **Not yet done.** Report not updated.

## 2026-09-29 - v1.2.0 release preparation

- Report v1.2: header, abstract, §3.5 (replicated-data check method), §4.4 (new paragraph and
  Fig. 7, verdict Partial, stat 2 named), discussion implications, limitations (vi) and next steps
  updated. The earlier statement that a practical PPC reference "was not tested" is removed. The
  pooled-threshold explanation for the X² false alarms is stated as untested.
- README status, new practical-PPC headline and limitation; supplement S9 and S13 item 6;
  `CITATION.cff` 1.2.0 (date 2026-09-29); checklist.

## 2026-09-29 - Engineering tidy-up (v1.2.1)

- `fit_one_hmetad()`: `backend = "rstan"` now passed explicitly (previously a recommendation).
  Check: grid cell 721 was refitted with `run_one_cell.R` after the change; `draws_b_sd` identical to
  the stored record (max abs diff 0), same aggregated counts, status and max R-hat (1.00206). The
  original result file was restored byte-for-byte afterwards.
- `compile_results.R`: the TODO about centralising `log_M` was stale (it already reads
  `design.yml`'s `truth:` block, as `run_one_cell.R` does); comment corrected and `cfg` reused.
  Rerun: all `data/processed/` outputs byte-identical.
- Makefile: new `calibrate` target (`validate_generators.R`, under a minute) now part of `all`;
  rerun reproduced `ddm_calibration.csv` and `sigma_c_pilot.csv` byte-for-byte. `analyse` now also
  runs `g2_ppp_fullfits.R` (~15 min).
- Tests: `testthat::test_dir("tests")` 54 pass, 0 fail. `make` itself is not installed on this
  machine, so the targets were run as their underlying `Rscript` commands, not through `make`.

## 2026-09-29 - v3 set-up: branch, locked constants, API checks

- Branch `v3-enhancement` from `main` (v1.2.1). Plan: `docs/v3_plan.md`. Constants and
  pre-specified rules: `config/v3.yml` (committed before any v3 fit).
- Environment: R 4.5.0, brms 2.23.0, hmetad 0.2.1, loo 2.8.0 (renv library active).
- API checks (plan §1.3), all "yes", so the main code paths are used:
  - (a) `brms:::loo.brmsfit` has `reloo`, `k_threshold`, `reloo_args`.
  - (b) `brms:::reloo.brmsfit` sets `ll_args$allow_new_levels <- TRUE` itself, with
    `sample_new_levels` defaulting to `"gaussian"`; `kfold.brmsfit` calls `log_lik(...,
    allow_new_levels = TRUE)`. No extra argument needed. reloo refits run through
    `future.apply::future_lapply` (sequential unless a `future` plan is set).
  - (c) `hmetad::aggregate_metad(data, ...)` takes tidy-select grouping columns;
    `aggregate_metad(d, participant, difficulty, K = 4)` gives one row per participant x
    difficulty and is identical to the `!!!rlang::syms(...)` form.
  - (d) `hmetad::epred_draws_metad(object, newdata, ...)` forwards `...` to
    `tidybayes::epred_draws()`, so `ndraws` (and `seed`) are accepted.

## 2026-09-29 - v3 step 1: relative misspecification bias (no refitting)

- Script `code/03_recovery_analysis/relative_bias.R`; outputs in `data/processed/v3/`:
  `g2_relative_bias_by_fit.csv`, `g2_relative_bias_by_cell.csv` (primary + pass-only),
  `g2_dprime_contrast_by_NT.csv`, `g2_dprime_contrast_pooled.csv`, `g2_delta_persistence_lm.csv`,
  `g2_confidently_wrong.csv`, `g2_baseline_vs_g0.csv`.
- Integrity checks passed: 240 paired datasets, same `sim_seed` for both variants, no error rows.
- `delta_mis` (Gaussian - correct, same dataset): +0.19 to +0.25 in the six d' = 0.75 cells,
  +0.11 to +0.15 in the six d' = 1.5 cells, matching the plan's sanity-check ranges.
- d' contrast (low - high, independent-sample SE): positive in 6/6 N x T cells (z 2.4 to 7.9);
  pooled +0.097 (SE 0.011).
- Persistence: slope on log2(T) = +0.0003 (95% CI -0.013 to +0.014); intercept 0.22; N term
  -0.006 (CI includes 0); d' = 1.5 term -0.097 (CI -0.118 to -0.075). The misspecification shift
  does not shrink with more trials, while the Gaussian interval narrows (mean width 0.99 -> 0.49
  at d' = 0.75), so the share of Gaussian intervals excluding the truth rises from 0.13 at T = 100
  to 0.35 at T = 400 (d' = 0.75; 0.05 -> 0.33 at d' = 1.5).
- Baseline: the correct (Gumbel) fit's own bias is -0.007 to -0.092; the difference from the G0
  bias in the same cell is within 2 SE in all 12 cells, so the small negative baseline is common
  to correctly specified fits and not a G2-specific effect.
- **Deviation from the plan's code:** in the pooled contrast, `n_cells_positive` was computed after
  `diff_low_minus_high` had been overwritten by its mean inside `summarise()`, so it counted a
  scalar (reported 1). Reordered; now 6.
- Understanding checks (plan §2.4):
  1. Each cell has its own seeds, so a low-d' and a high-d' replication with the same `rep_id` share
     no data; pairing them would claim a correlation that does not exist. The contrast is between
     two independent means, so the variances add.
  2. A slope of -0.01 with a CI covering 0 means no detectable shrinkage over a fourfold increase
     in T: the shift behaves like a pseudo-true displacement, not a small-sample bias. A slope of
     -0.05 with a CI excluding 0 would mean the shift shrinks with data (about 0.1 over the grid),
     i.e. partly a finite-sample effect. The observed slope is +0.0003, the first case.
  3. It shows the correct-model baseline error is the same small negative bias seen in G0, so it
     belongs to the fitting procedure (prior/shrinkage), not to the Gumbel generator. `delta_mis`
     then isolates the misspecification effect.

## 2026-09-29 - v3: fit wrapper extension (covariates / multi-column aggregation)

- `fit_one_hmetad()` gains `agg_by`, `dprime_c_covariates`, `log_M_covariates`, `log_M_b_prior`
  (defaults NULL = v1.2.1 behaviour); `.build_metad_formula()` / `.build_metad_priors()` extended.
  The record now also stores `agg_by` and the covariate lists.
- Regression fixture `tests/fixtures/formula_k4_v121.rds` was written from the unmodified v1.2.1
  code and committed first (f1f9d01). `tests/test_formula_backcompat.R`: default formula and priors
  identical to the fixture; covariates land only in the intended formula parts; a covariate model
  (condition on dprime/c and log_M, hierarchical thresholds, gumbel_min) builds an empty brmsfit.
- Reproducibility check (plan §4.2 step E): grid cell 721 refitted with the modified code via
  `run_one_cell.R`; `draws_b_sd` identical to the stored record (max abs diff 0), identical `agg`,
  status `pass`, max R-hat 1.00206. Original file restored (md5 591034d8... unchanged).
- Tests: 76 pass, 0 fail (includes the new `test_simulate_g3.R`).

## 2026-09-30 - v3 step 2: exact-refit LOO on the 48 stored G2 fits

- Scripts: `code/04_ppc_and_comparison/v3_reloo_stored_fits.R` (3 shards x 4 cores, ~1.3 h wall
  clock; records in `data/interim/v3_reloo/`), `v3_loo_robust_summary.R`. Outputs:
  `data/processed/v3/g2_loo_psis_vs_exact_by_pair.csv`, `g2_loo_psis_vs_exact_summary.csv`,
  `g2_pareto_k_by_cell.csv`.
- 30 of 48 fits had at least one participant with Pareto k > 0.7; 142 leave-one-participant-out
  refits in total (4 to 13 per affected fit), all succeeded. Refit seeds = the stored fit's seed.
- Result (sign as in `g2_elpd_comparison.csv`: > 0 favours the correct model): correct favoured in
  23/24 pairs under both PSIS and exact LOO; > 2 SE in 16/24 under both. Sign agreement 24/24,
  2-SE agreement 24/24, median |change| 0.028 elpd, max 0.87 (N = 40, T = 200, d' = 0.75, rep 1:
  20.77 -> 19.91, SE 6.6).
- Decision (plan §3.5): `twose_agreement` = 1.00 >= 0.9 and the favour rate moves 0 points, so the
  PSIS-LOO conclusion stands on this subset; the optional K-fold (§3.4) is not run. The remaining
  216 pairs have no stored fit and cannot be refitted; their Pareto k profile by cell is in
  `g2_pareto_k_by_cell.csv`.
- **Deviations from the plan's code** (brms 2.23.0):
  1. `reloo_args = list(check = FALSE, ...)` errors ("formal argument 'check' matched by multiple
     actual arguments"): `loo.brmsfit` already passes `check`. Removed.
  2. Passing `cores = 4` in `reloo_args` also reaches `log_lik()`, which on Windows then runs on a
     PSOCK cluster whose workers lack `gumbel_min_lcdf` ("object 'gumbel_min_lcdf' not found").
     Sampler cores now come from `options(mc.cores = 4)` (brm's default); `log_lik()` stays
     serial. Refit seed passed as `reloo_args = list(seed = r$seed)`.
  3. The brms-version fallback to `brms::reloo()` was dropped: the §1.3 check showed
     `loo(reloo = TRUE)` exists.
- reloo sets the refitted participants' Pareto k to 0 in `loo_exact` (checked on the trial fit).

## 2026-09-30 - v3 step 4 (part 1): data access, screening, manual coding (no fit)

- Confidence Database downloaded 2026-09-30 from OSF `s46pr` (361 files, 255 MB, all md5-verified;
  licence CC0 1.0). Record: `docs/data_access_confidence_db.md`; manifest
  `data/processed/v3/empirical/raw_manifest.csv`. `readxl` (+ `cellranger`, `rematch`) added to
  `renv.lock` (additions only).
- Metadata sheet checked before use: file `Database_Information.xlsx`, sheet
  `Database_Information`, columns `Name_in_database` and `Category` (the plan's guesses were right).
  Four datasets have no metadata row (Bocheva_unpub_Expt1/2, Rahnev_2021, Zheng_2023_NOC); with
  no category they cannot enter any set.
- Screening (`01_screen_datasets.R` -> `screening_table.csv`): 66 of 180 auto-eligible; 33
  perception, 20 memory, 13 other categories.
- **Deviations from the plan's screening code (fixed before any real-data fit):**
  1. `rule_discrete` used `conf_integer`. The rule in `config/v3.yml` is "discrete scales only;
     3-11 levels", but the integer test rejects discrete probability scales (0.5, 0.6, ..., 1:
     Hainguerlot_2018/unpub, Lebreton_2018, Massoni_unpub). The rule is now "numeric with 3-11
     distinct values". Four more datasets eligible.
  2. `standardise_names()`: case-insensitive renaming of the required/optional columns and
     `subject_id` -> `Subj_idx` (e.g. Xue_2024 uses `stimulus`, `confidence`). Datasets with one
     column per task still fail the required-column rule.
  3. Row filters, fixed per dataset in `config/empirical_manual_coding.csv` and applied by
     `filter_rows()` before the participant exclusions: practice rows (`Training == 1`)
     whenever that column exists; an optional `exclude_filter` (catch trials in Bang_2019_Exp2;
     training and distractor rows in Siedlecka_2019_Exp1/2); the valid confidence range
     `conf_min`-`conf_max`, which drops sentinel codes (0 = "error" in Gajdos_2019, 999 in
     Rouault_2020, values outside 1-5 in Weidemann_2016). Without these, practice trials and
     sentinel codes would enter the model as confidence levels.
  4. `rank_within_subject`: Rouault_2020 has two fixed difficulty levels calibrated per
     participant (raw values differ across participants), so the level is the within-participant
     rank.
  5. The <= 4-level check uses the levels of the difficulty column actually modelled (after the
     row filters), not the `Condition` column's count.
  6. `03_prepare_datasets.R` marks a dataset unusable if `acc_agreement < 0.99` or
     `conf_acc_rho <= 0` (the plan's §5.5 checks, made automatic).
- Manual coding (`config/empirical_manual_coding.csv`, 53 datasets = every auto-eligible
  perception or memory dataset): coded from each readme, the metadata sheet, and counts of distinct
  difficulty values per participant (to tell a per-participant calibration from a trial-by-trial
  staircase). No model had been fitted to any real dataset. Perception (33): 19 constant or
  recorded_levels, 7 staircase, 4 unrecorded_varied (more than 4 difficulty levels), 3 unclear
  (Desender_2021_Cognit: scale differs by condition; OHora_unpub_2: signed wager; Zheng_2023:
  binary confidence). Memory (20): 19 constant or recorded_levels (Kantner_2010 and
  Kantner_unpub2 have 6 conditions and fall to the 4-level rule), 1 unrecorded_varied. Where the
  modelled condition is not difficulty (speed/accuracy instruction, feedback, rating order,
  material), the notes say so; the plan allows any discrete factor with <= 4 levels.
- Selection (`02_select_datasets.R`) is written but not run: it reads the G3 verdict (plan
  §4.7: perception `unrecorded_varied` datasets enter a separate `sensitivity_unrecorded` set
  only if G3 finds no pooling artefact), so it runs after the G3 summary, then the
  `v3-prereg-empirical` tag.

## 2026-09-30 - v3 step 3: G3 difficulty-mixture simulation (result)

- Rules locked in `config/v3.yml` and tagged `v3-prereg-g3` before any G3 fit. 160 fits
  (2 conditions x 20 reps x 4 variants), 4 shards x 4 cores, ~6.5 h. Outputs:
  `data/processed/v3/g3_by_fit.csv`, `g3_loo_by_rep.csv`, `g3_loo_rates.csv`, `g3_bias.csv`,
  `g3_delta_logM.csv`, `g3_verdict.txt`; Fig. 8.
- One fit (g3_id 15, control rep 4, normal_difficulty) first ended with status `error`:
  "cannot open the connection" / "port 11908 cannot be opened" (rstan's local socket while four
  fits ran concurrently), not a sampling failure. The error record was deleted and the same id
  rerun with the same seeds: `pass`. All 160 fits now pass or were escalated to pass (2 escalated).
- **Verdict (pre-specified rule): no pooling artefact.** The pooled comparison favoured Gumbel-min
  by > 2 SE in 0/20 mixture and 0/20 control replications; the Gaussian (true) model was favoured
  by > 2 SE in 20/20 in every condition x aggregation (median elpd difference +28.7 mixture pooled,
  +30.8 control pooled, +57.1 mixture with difficulty modelled).
- Gaussian (correct) fits: log M bias -0.014 to -0.017, coverage 0.85-1.00. Gumbel-min fits on the
  Gaussian data: bias -0.46 to -0.50, coverage 0.
- **Plan checkpoint §4.7 not met as written.** The plan expected the difficulty-version
  delta log M (normal - gumbel) to be about 0 "because the data are Gaussian". It is +0.45 to
  +0.48 (MCSE 0.01) in every condition and aggregation. Investigated before step 4: the correctly
  specified Gaussian fits are unbiased, so the non-zero difference is the misspecified Gumbel
  fit's shift, the mirror image of G2 (there the Gaussian fit on Gumbel data was shifted by
  +0.11 to +0.25). A zero family difference was never implied by Gaussian data; the pipeline shows
  no fault, so step 4 proceeds. Consequence for the empirical analysis: the family difference in
  log M is large whichever family is wrong, so `delta_logM` must be read together with the LOO
  preference, not as evidence by itself.
- Consequence for step 4 (plan §4.7, rule written into `02_select_datasets.R` before the verdict):
  perception datasets coded `unrecorded_varied` enter the separate `sensitivity_unrecorded` set.

## 2026-09-30 - v3 step 4 (part 2): selection, preparation, pre-registration tag

- `02_select_datasets.R` (G3 verdict = no artefact): 19 primary, 7 sensitivity (staircase),
  4 sensitivity_unrecorded, 17 secondary (memory), 5 excluded (3 perception `unclear`;
  Kantner_2010 and Kantner_unpub2 with 6 conditions). OHora_unpub_2 was dropped earlier by
  `conf_higher_is_more = FALSE`. 19 primary <= 20, so no sampling.
- `03_prepare_datasets.R` -> `prepare_log.csv`: 45 of 47 usable. Gajdos_2019 and OHora_2017 keep
  19 participants after the pre-specified exclusions (< min_participants 20) and drop out of the
  primary set (17 primary remain). All data checks passed: `acc_agreement` = 1 wherever the dataset
  has an Accuracy column (19 datasets), and `conf_acc_rho` > 0 everywhere (0.10 to 0.40).
- Tag `v3-prereg-empirical` placed on this commit, before any model was fitted to real data.

## 2026-09-30 - v3 step 4 (part 3): trial fits and sampler deviations (before the main run)

- Trial fits (plan §5.7) on the smallest (Maniscalco_2017_expt3, 21 participants) and largest
  (Rouault_2018_Expt1, 498 participants) prepared datasets, both families, default settings:
  - Maniscalco normal: pass (554 s). Maniscalco gumbel_min: 145 divergent transitions at
    adapt_delta 0.95 and again after escalation to 0.99 -> `fail` (R-hat 1.00, min bulk ESS 1287).
  - Rouault normal: no chain initialised ("Rejecting initial value ... multinomial_logit_lpmf:
    log-probabilities parameter is -inf"); the fit had no draws and the script stopped. With 498
    participants and participant-level thresholds, Stan's default random inits on (-2, 2) almost
    always push some participant's type-2 cell probability to zero. A one-chain test with
    `init_r = 0.5` initialised after 2 rejections and sampled normally.
  - Rouault gumbel_min was still sampling after ~65 min when the trials were stopped.
- **Deviations, fixed in `config/v3.yml$empirical` before the main run and applied to every
  empirical fit and every reloo/K-fold refit:** `init_r: 0.5`; `adapt_delta_start: 0.99` (the
  plan's own §5.7 remedy); escalation retry at adapt_delta 0.999 / max_treedepth 14 (design.yml's
  0.99 / 14 is already the starting point). The four trial fits were discarded and are redone under
  these settings, so all empirical fits share one configuration.
- `04_fit_dataset.R` now records a fit that errors (e.g. no draws) as status `error` instead of
  stopping, so the dataset is categorised `unreliable` by the pre-specified rule.
- Rerun of the trials under the new settings: Maniscalco normal `pass` (975 s); Maniscalco
  gumbel_min still 175 divergent transitions after escalation to adapt_delta 0.999 -> `fail`
  (R-hat 1.004): a geometry problem, not a step-size one. Kept as is: by the pre-specified rule
  this dataset is `unreliable`. Both Rouault_2018_Expt1 fits (498 participants) were still
  sampling after 2 h (started 07:43, stopped 09:47).
- **Deviation (plan §5.7 remedy, fixed before the main run):** `max_participants_for_fit: 100`.
  After the pre-specified exclusions, a dataset with more than 100 participants keeps a random
  sample of 100 (`withr::with_seed(seed_base_v3 + sum(utf8ToInt(dataset)))`, before
  confidence-level merging). Affects 10 datasets: Bang_2019_Exp2 (167), Haddara_2022_Expt1 (397),
  Fallow_unpub_1/2/3 (134/165/136), Kantner_2012_E3 (147), Weidemann_2016 (143), Lebreton_2018
  (111), Rouault_2018_Expt1/2 (498/497). `prepare_log.csv` records both counts. Maniscalco_2017_expt3
  is unaffected, so its two trial fits (already under the final settings) are kept.

## 2026-09-30 / 10-01 - v3 step 4 (part 4): post-registration prior deviation

- **Trigger.** The main empirical run (5 shards, started 2026-09-30 09:48, configuration of
  `acc2b8f` + `bc96f19`) was stopped at 17:40 after 16 of the first 18 completed fits failed the
  pre-registered diagnostics. Gaussian fits: divergences in most fits (up to 3,887 of 4,000
  draws), non-converged chains (max R-hat 2.05 Hainguerlot_2018, 1.56 Desender_2022_Exp1; bulk
  ESS 5-7). Gumbel-min fits: mostly bulk ESS 180-370 (< 400) or R-hat 1.01-1.03. Continuing would
  have left nearly every dataset `unreliable`, and unevenly by family (Gaussian worse), so the few
  passing pairs would be a selected subset.
- **What was looked at before deciding.** Only convergence diagnostics: per fit, status, flags,
  divergence count, max R-hat, min bulk/tail ESS, tree-depth hits; for one fit (Gherman_2018
  normal) the names, R-hat and bulk ESS of the 12 lowest-ESS parameters (the weakest was
  `sd_participant__Intercept`, the participant-level SD of log M); and that fit's prior summary
  (all participant-level SDs on brms's default `student_t(3, 0, 2.5)`). No LOO, elpd, log M
  estimate or category of any empirical fit was computed or viewed.
- **Decision (user, 2026-09-30).** Pilot an explicit SD prior plus longer chains, then refit all
  datasets under it. `config/v3.yml$empirical`: `sd_prior: "normal(0, 0.5)"` on every
  participant-level SD (log M, d', c, and the thresholds), `warmup: 2000`, `iter_sampling: 2000`.
  Implemented as an optional `sd_prior` argument of `fit_one_hmetad()` / `.build_metad_priors()`
  (NULL default = v1.2.1 priors; regression tests unchanged and passing, new test checks that
  every SD prior is replaced).
- **Pilot (same settings, fits kept as the real fits).** Gherman_2018 normal: fail -> pass
  (R-hat 1.005, bulk ESS 998). Gherman_2018 gumbel_min: fail -> pass (R-hat 1.007, ESS 998).
  Hainguerlot_2018 normal: still fail, 7,694 of 8,000 draws divergent, R-hat 1.26, ESS 13 (a
  structural problem with that model on that dataset; it will be `unreliable` by the rule).
  Desender_2022_Exp1 normal: interrupted when the session ended; rerun.
- **Comparison set kept.** The 34 fits made under the pre-registered configuration are kept in
  `data/interim/v3_empirical/fits_prereg/` (not read by any summary script); their diagnostic
  failure rate is itself a reported result.
- **Limitation / check.** `normal(0, 0.5)` also limits the between-participant spread of log M,
  a setting the G0-G2 simulations (default SD prior, pooled thresholds) did not validate. A
  small validation run under the full empirical configuration follows (next entry).

## 2026-10-01 - v3: validation of the empirical configuration on G0/G2; pre-specified SD check

- `code/03_recovery_analysis/v3_sdprior_validation.R` refitted 30 grid rows (G0, G2 correct, G2
  Gaussian; N = 40, T = 200; d' 0.75 and 1.5; reps 1-5) under the full empirical configuration
  (sd_prior normal(0, 0.5), hierarchical thresholds, 2000 + 2000 draws, init_r 0.5, adapt_delta
  0.99) on the same simulated datasets as the stored v1 fits. `..._summary.R` ->
  `data/processed/v3/sdprior_validation_{by_fit,summary,delta_mis}.csv`.
- 30/30 pass, none escalated, 0 divergences, max R-hat 1.005. log M moves up by 0.004-0.023 on
  average (v3 - v1, same data); intervals 3-5% narrower; bias v1 -> v3: G0 -0.057 -> -0.034 and
  +0.023 -> +0.027; G2 correct -0.031 -> -0.020 and -0.056 -> -0.046; G2 Gaussian +0.179 -> +0.193
  and +0.135 -> +0.148 (d' 0.75 / 1.5). Coverage (of 5) unchanged except G2 correct d' 1.5 4 -> 5
  and G2 Gaussian d' 1.5 5 -> 3 (5 reps per cell: not interpretable as a pattern).
  delta_mis (Gaussian - correct): 0.210 -> 0.213 (d' 0.75), 0.191 -> 0.194 (d' 1.5). Recovery is
  comparable to v1.
- **Limitation of this check (raised in review):** the G0/G2 simulators set sd_M = sd_dprime =
  sd_c = 0, the most favourable case for a prior that pulls SDs towards 0; over-shrinkage when
  participants really differ would not show here. Two additions, fixed now:
  1. `v3_sdprior_hetero_validation.R`: Gaussian data with sd_M = 0.5 (log scale) and sd_dprime =
     0.3 (N = 40, T = 200, d' 1.5, 5 reps), each fitted with the default SD prior and with
     normal(0, 0.5); reports log M population-mean bias/coverage and SD recovery. Runs alongside
     the main empirical fits.
  2. **Pre-specified before any empirical LOO was computed** (`config/v3.yml$empirical$sd_prior_check`,
     `07_summarise_empirical.R`): every dataset reports the posterior median and 97.5% quantile of
     `sd_participant__Intercept` for both families; a dataset is flagged "prior may over-shrink" if
     either 97.5% quantile exceeds 1.0. The flag is reported next to the category and does not
     change it.
- **Heterogeneity check result** (`sdprior_hetero_{by_fit,summary}.csv`; true sd_M = 0.5,
  sd_dprime = 0.3, log M = -1; 5 reps, same data under both priors): 10/10 pass. Default SD prior
  vs normal(0, 0.5): log M bias -0.072 vs -0.053, coverage 5/5 vs 5/5; estimated sd_M 0.574 vs
  0.535 (bias +0.074 vs +0.035), sd_M coverage 5/5 vs 5/5; sd_dprime 0.336 vs 0.332, coverage
  5/5 vs 5/5. The tighter prior lowers the SD estimate by ~7% and the upper 95% limits from ~1.0
  to ~0.9. Conclusion: comparable; no evidence of over-shrinkage at a true SD of 0.5 (n = 5 per
  prior). The between-prior differences in bias and SD estimate are within Monte Carlo error at
  n = 5 and are not a finding. (An earlier version of this entry said the tighter prior was
  "closer to the truth"; corrected 2026-10-02.)
- **Limitation:** only one true SD (0.5) was tested. Real data with larger between-participant
  spread in log M (SD near 1, the tail of normal(0, 0.5)) are not covered by this check; the
  pre-specified `sd_prior_check` flag (posterior 97.5% quantile > 1.0) is the safeguard for that
  case in the empirical analysis.

## 2026-10-02 - v3: exploratory analyses pre-specified before any empirical LOO is read

- **Why.** Two of the first seven fits under the new configuration show the same pattern:
  the Gaussian fit fails only through divergences while the Gumbel-min fit on the same dataset
  passes (Chandravadia_2020: 1,035 divergences, R-hat 1.003, ESS >= 669; Hainguerlot_2018 is
  the other, there with R-hat and ESS also failing). If the failing family is mostly the
  Gaussian one, the primary rule ("either family fails -> unreliable") removes datasets
  non-randomly, and the remaining datasets would lean towards "no difference / Gaussian".
  Divergence is a diagnostic signal, not model-comparison evidence.
- **State when this was fixed.** Only convergence diagnostics have been seen. PSIS-LOO objects
  are stored inside each fit record but none has been read; `05_loo_repair.R`, `06_ppc_dataset.R`
  and `07_summarise_empirical.R` have not been run on any empirical fit.
- **Added (exploratory; `config/v3.yml$empirical$exploratory`, `07_summarise_empirical.R`):**
  1. Diagnostic failure rates by family, with divergences, R-hat, bulk ESS, tail ESS and tree
     depth counted separately (`exploratory_diagnostics_by_{fit,family}.csv`), and a paired
     table of which family failed within each dataset (neither / Gaussian only / Gumbel only /
     both; `exploratory_diagnostics_paired.csv`) with an exact binomial test on the discordant
     pairs, reported descriptively.
  2. A divergence-only sensitivity categorisation (`category_div_sens`,
     `exploratory_category_divergence_sensitivity.csv`): the same 2-SE rule, but a fit counts as
     usable if it passed or failed only on divergences (R-hat <= 1.01, bulk and tail ESS >= 400,
     no tree-depth hits). Reported next to the primary categories.
- The primary categorisation and every other rule are unchanged. `05_loo_repair.R` already
  repairs LOO for fits with status `fail` (it skips only missing fit or loo objects), so the
  sensitivity analysis needs no change there.

## 2026-10-04 - v3 step 4 (part 5): LOO repair set-up (paused; not yet run)

- **Empirical fits complete** (2026-10-04 02:10): 90/90, no errors. Gaussian 11 pass / 34 fail
  (11 divergence-only); Gumbel-min 31 pass / 14 fail (2 divergence-only). Per dataset: both pass
  10, Gaussian-only fails 21, Gumbel-only fails 1, both fail 13; usable under the divergence-only
  sensitivity rule 22 of 45. (Diagnostics only; no LOO read.)
- **LOO repair method.** Pareto k > 0.7 for essentially every participant (`prop_bad` = 1.000 in
  every dataset checked), so the pre-specified rule (> 10% bad k -> grouped K-fold) sends every
  dataset to grouped 5-fold cross-validation: 450 refits (45 datasets x 2 families x 5 folds),
  each on ~80% of the participants. This is the pre-specified rule and is not skipped.
- **First launch (2026-10-04 02:20, 5 shards), stopped at 02:50 on the user's request.** It first
  failed on `future`'s 500 MB export limit (fits are 0.55-0.86 GB): `options(future.globals.maxSize
  = Inf)` added (sequential plan, nothing copied); failed records deleted; relaunched; paused with
  no record written.
- **Changes before the production run (execution only; no change to the analysis):**
  1. Refit sampler settings passed explicitly (`loo_repair_functions.R::refit_args()`): the
     fit's own settings, i.e. adapt_delta 0.99 / max_treedepth 12, or 0.999 / 14 for escalated
     fits; 4 chains; 2000 warmup + 2000 draws; init_r 0.5; the fit's seed. Checked: brms 2.23's
     `update.brmsfit` (used by `kfold()`/`reloo()`) already copies `control`, `warmup`, `iter` and
     `chains` from the stored fit (e.g. Gherman_2018 normal: stored control adapt_delta 0.999,
     max_treedepth 14), so the refits would not have fallen back to adapt_delta 0.8; passing them
     makes this explicit.
  2. Folds, method choice and the output record moved to `loo_repair_functions.R`, shared by
     `05_loo_repair.R` and the new pilot `05a_kfold_pilot.R`, so both use identical folds, seeds
     and settings.
  3. Datasets processed primary set first (then sensitivity, sensitivity_unrecorded, secondary)
     before sharding, so the primary results arrive first; folds and seeds depend only on the
     dataset name, so the order cannot change any result. Run with 4 shards, not 5: with 5 shards
     only ~5 GB of 31.4 GB RAM was free (each shard holds both fits of a dataset, 1-1.7 GB, plus
     the refit in progress).
- **Pilot before production (`05a_kfold_pilot.R`, run alone).** Gherman_2018 (30 participants,
  both families pass) with `save_fits = TRUE`: per family x fold, adapt_delta, max_treedepth,
  iter/warmup/chains, divergent transitions, max R-hat and min bulk ESS ->
  `kfold_pilot_diagnostics.csv`. Both Gherman fits were escalated, so the refits should show
  adapt_delta 0.999 / treedepth 14. Pass criterion: few or no divergences and R-hat <= 1.01; if
  the refits diverge heavily, stop and report before the production run. The pilot writes the
  production-format repair records for Gherman_2018 (refits dropped, ~3 GB not kept), so the
  production run skips it. The report will state that refit convergence was checked on the pilot
  dataset only (production refits keep no diagnostics).
- **Time.** The production fits took ~55 h wall clock for ~85 fits on 4 shards. 450 refits on
  ~80% of the data suggests roughly 7-10 days on 4 shards; to be updated from the measured rate.
  The earlier 2-4 day estimate was too optimistic.
- **Tiered execution order (user decision 2026-10-04; execution only).** `05b_loo_tiers.R` ->
  `loo_repair_tiers.csv`, from fit statuses and diagnostics only (no LOO read): tier 1 = both
  families pass (10 datasets: 2 primary, 7 secondary, 1 sensitivity_unrecorded), tier 2 = both
  `conv_ok` but not both pass, i.e. at least one divergence-only failure (12: 3 primary, 6
  secondary, 2 sensitivity, 1 sensitivity_unrecorded), tier 3 = at least one fit fails on R-hat,
  ESS or tree depth (23: 12 primary, 4 secondary, 5 sensitivity, 2 sensitivity_unrecorded).
  `05_loo_repair.R` runs tier 1, then tier 2, each primary set first, sharded 4 ways; tier 3 only
  with `--include-tier3`. Tier-3 datasets are `unreliable` under both the primary rule and the
  divergence-only sensitivity rule whatever their LOO, so **no pre-specified category depends on
  tier-3 LOO**; tier 3 is deferred, to be run later only if CPU time allows. Consequences: repaired
  LOO will exist only for tiers 1-2 (~220 refits, roughly 3.5-5 days); Fig. 9 shows tier-3
  datasets with the unrepaired PSIS comparison, marked as such. Note: only 5 of the 17 primary
  datasets are in tiers 1-2, so the primary categorisation will rest on few datasets.
- The divergence-only test now lives in `loo_repair_functions.R` (`divergence_only()`,
  `conv_ok()`) and is used by both `05b_loo_tiers.R` and `07_summarise_empirical.R`.
- **PPC fix (`ppp_functions.R`).** stat 3 (Pearson X2/df) was `NA` in about a third of empirical
  fits: cells where a draw's predicted probability underflows to exactly 0 and the count is also 0
  gave 0/0. Such cells now contribute 0; a positive count with expected 0 still gives Inf.
  `tests/test_ppp_functions.R` still reproduces the v2 p-values exactly (11/11 pass). The
  empirical PPC run that had started with the old code was stopped and restarted.
- **Empirical PPC run** (`06_ppc_dataset.R`, fixed code, 2026-10-04 11:58-12:19) ->
  `data/processed/v3/empirical/ppc_by_fit.csv`: 89 of 90 fits, no `NA` statistic. Flags
  (p < 0.05), Gaussian / Gumbel-min: stat 1 27/45 and 38/44, stat 2 18/45 and 38/44, stat 3 32/45
  and 37/44. These are model-fit checks only; no pre-specified category uses them.
- **Not computed: Schurgin_2018 gumbel_min** (tier 2). The PPC's built-in check (per-draw cell
  probabilities sum to 1 within 1e-8) failed: for one participant (#17) the R-side Gumbel-min CDF
  at extreme threshold values gives sums of 0.986-1.003 in 84 of 396,000 participant x draw groups
  (0.02%); all other fits pass the check. The tolerance was not loosened after the fact; this
  fit's PPC is reported as not computed (numerical check failed). The same R-side functions feed
  `log_lik()`, so this participant's LOO contributions in this fit carry the same small numerical
  error; noted for the Schurgin_2018 sensitivity-analysis result.
- **K-fold pilot result** (`05a_kfold_pilot.R`, Gherman_2018, 2026-10-04 11:36-13:36, run with
  only the PPC alongside) -> `kfold_pilot_diagnostics.csv`. All 10 refits (2 families x 5 folds)
  used adapt_delta 0.999 / max_treedepth 14 (both Gherman fits were escalated), 2000 warmup +
  2000 draws, 4 chains, as intended. Max R-hat 1.009; min bulk ESS 761; 6 divergent transitions
  in total over 80,000 draws (Gaussian folds 3 and 5: 4 and 2). Meets the pass criterion (few or
  no divergences, R-hat <= 1.01), so the production run proceeds. Each family's 5 refits took
  ~1 h. The two production-format repair records for Gherman_2018 were written (refits dropped);
  their LOO values have not been read. Refit convergence is checked on this dataset only;
  production refits keep no diagnostics.
- **LOO repair complete (tiers 1-2)**, 2026-10-04 13:37 -> 2026-10-06 19:24: 44/44 repair records
  (22 datasets x 2 families, grouped 5-fold K-fold), all `ok`. Tier 3 (23 datasets) not run, as
  decided. No repaired LOO value has been read yet.
- Execution notes: on 2026-10-05 21:00 two extra workers took Fallow_unpub_2 and
  Siedlecka_2019_Exp2 from shard 2's queue (`05_loo_repair.R --dataset NAME`, added for this;
  results are identical whoever computes them, since folds and seeds depend only on the dataset
  name). At 2026-10-06 00:10 two running records failed at the same second with "error writing to
  connection" (Fallow_unpub_2 normal after 1.0 h, Schurgin_2018 gumbel_min after 8.0 h); the
  laptop was shut down that night. Not a modelling failure; disk had 159 GB free. The two failed
  records were deleted and the three outstanding records (Fallow_unpub_2 x 2, Schurgin_2018
  gumbel_min) rerun on 2026-10-06 from 08:34; all ok (Schurgin_2018 gumbel_min took 10.8 h).
  The deleted Schurgin record briefly reappeared (Synology Drive restored it from its server copy)
  and was overwritten by the rerun. All 44 records were re-read and checked `ok` afterwards.

## 2026-10-06 - v3 step 4 (part 6): empirical summary (pre-specified + exploratory)

- `07_summarise_empirical.R` (2026-10-06, first read of any repaired LOO) ->
  `data/processed/v3/empirical/empirical_by_dataset.csv`, `empirical_category_summary.csv`,
  `empirical_condition_contrasts.csv`, `exploratory_diagnostics_{by_fit,by_family,paired}.csv`,
  `exploratory_category_divergence_sensitivity.csv`. All 22 repaired comparisons use grouped
  5-fold K-fold. Category counts reconcile with the tiers (10 tier-1 datasets categorised under
  the primary rule, 22 under the divergence-only rule).
- **Primary rule** (elpd(Gaussian) - elpd(Gumbel-min), 2 SE; unreliable if either fit not pass):
  primary 2 clear_gaussian / 15 unreliable (Gherman_2018 +132 SE 50; OHora_unpub_1 +133 SE 40);
  secondary 1 clear_gaussian (Hu_2017) / 5 clear_gumbel / 1 inconclusive / 10 unreliable;
  sensitivity 7/7 unreliable; sensitivity_unrecorded 1 inconclusive / 3 unreliable.
- The 5 clear_gumbel datasets are all old/new word or painting recognition from one lab
  (Kantner_2012_E1/E3, Kantner_2014_E1/E2, Lindsay_2014; elpd_diff -82 to -251), with 3-level
  confidence derived from a 6-point old/new scale. They are not independent; the memory result
  rests on one paradigm.
- **Divergence-only sensitivity (exploratory):** primary 3 clear_gaussian / 2 inconclusive / 12
  unreliable; secondary 6 clear_gaussian / 5 clear_gumbel / 2 inconclusive / 4 unreliable;
  sensitivity 1 clear_gaussian / 1 inconclusive / 5 unreliable; sensitivity_unrecorded 1
  clear_gaussian / 1 inconclusive / 2 unreliable. No dataset changes direction between rules;
  the extra datasets admitted all come out clear_gaussian or inconclusive.
- **Diagnostics by family (exploratory):** failure rate Gaussian 0.76 vs Gumbel-min 0.31
  (divergences 0.67 vs 0.18; R-hat 0.49 vs 0.24; bulk ESS 0.33 vs 0.13; tail ESS 0.27 vs 0.04).
  Paired: Gaussian-only failures 21, Gumbel-only 1, both 13, neither 10 (exact binomial on
  discordant pairs p < 0.001; descriptive).
- **delta_logM (Gaussian - Gumbel-min):** median by set 0.47 primary, 0.14 secondary, 0.38
  sensitivity, 0.43 sensitivity_unrecorded; positive in all perception datasets. In the 5
  clear_gumbel datasets it is small and negative (-0.04 to -0.18). Note from G3: a large positive
  family difference also arises when the Gaussian model is correct, so delta_logM is not evidence
  for either family by itself.
- **Pre-specified SD-prior check:** 5 of 45 datasets flagged (posterior 97.5% quantile of the
  participant-level log M SD > 1.0 in either family): Desender_2022_Exp1, OHora_unpub_1,
  Rausch_2020, Siedlecka_2019, Yeon_unpub_Exp1. Only OHora_unpub_1 is categorised (clear_gaussian;
  flagged by its Gumbel-min fit, q97.5 1.008). Reported next to its category, as pre-specified.
- Condition contrasts: 5 of 27 change their "excludes 0" conclusion between families.

## 2026-10-06 - v3 release documentation and tests

- Full test suite: 129 expectations in 7 files, 0 failed, 0 errors, 0 skipped
  (test_data_format 25, test_discretise_confidence 12, test_eligibility 38,
  test_formula_backcompat 19, test_ppp_functions 11, test_simulate_g1_ddm 17, test_simulate_g3 7;
  includes the PPP regression against the stored v2 p-values, which needs the stored G2 fits).
- README: v3 status and results section (steps 1-4), repository map, v3 reproduction
  (`run_v3.R`, Makefile v3 targets, data access), v3 diagnostic policy. design_decisions.md: v3
  section (locked rules, tags, all deviations in order) and v3 "must not claim" items.
  computational_environment.md: v3 packages, compute times, Windows/`future` settings, sync
  hazard; verification-log rows. CITATION.cff: 2.0.0, dated 2026-10-06 (update the date if the
  `v2.0.0` tag is made on another day).
- Fig. 9: `geom_errorbarh()` (deprecated in ggplot2 4.0) replaced by
  `geom_errorbar(orientation = "y")`; figure unchanged.
- Not yet done: merge `v3-enhancement` into `main`, tag `v2.0.0`, Zenodo DOI; the report
  (manuscript/) still covers v1.2 only.

## 2026-10-06 - Report draft v2.0

- `manuscript/report.md`: header and abstract extended; §2 v2.0 questions (incl. RQ4); new §3.6
  (methods of the four extensions, the empirical pipeline and every deviation); §4.3 Pareto-k
  caveat updated; new §4.8-4.11 (relative bias, exact-refit LOO, G3, empirical); discussion
  paragraph on the extensions; limitations (v), (xi) updated and (xiii) added; next steps revised;
  reproducibility statement extended. Report Figs. 8-11 = `outputs/figures/v3/fig_6`-`fig_9`.
- `references.bib`: Rahnev et al. (2020), verified against Crossref 2026-10-06. The per-dataset
  sources of the Confidence Database datasets are not yet in the bibliography (noted in §7).
- `supplementary_methods.md`: S14 pointer to the v2.0 specification and deviations.
- All report numbers taken from `data/processed/v3/` and the v3 analysis-log entries.

## 2026-10-06 - Per-dataset citations for the empirical analysis

- Citation lines were extracted from the readmes of all 45 analysed datasets: 24 distinct published
  sources and 9 unpublished contributions. Each published source was checked against Crossref
  (by the readme's DOI where given, else by bibliographic search), comparing title, authors, year,
  journal, volume, issue and pages with the readme; 18 matched as given. Haddara & Rahnev (2022)
  was first matched to its 2020 preprint and corrected to the Psychological Science article. Four
  readmes cite preprints that Crossref links to later articles (Faivre 2018 -> Cortex 2020; Schurgin
  2018 -> Nature Human Behaviour 2020; Siedlecka 2019 -> Consciousness and Cognition 2020; van Boxtel
  2019 -> Orchard et al., Journal of Vision 2022); the published articles are cited and the preprint
  DOIs recorded in comments. Lindsay, Kantner & Fallow (2014) is a book chapter not indexed by
  Crossref; the book (doi:10.4324/9781315752808, 2014, editors) was checked, the chapter page range
  was not.
- `references.bib` now has 32 entries (8 previous + 24 dataset sources), generated from the Crossref
  records rather than retyped. `supplementary_methods.md` S15 lists every analysed dataset with
  set, N, pre-registered category and source (unpublished ones with the contributors named in their
  readmes). Report §4.11 cites the named datasets' sources and §7 lists all of them.

## 2026-10-14 - Status: working paper; pre-submission plan paused

- Decision (user): not submitting for now. `v2.0.0` stays the current release; no Zenodo DOI is minted.
- README status updated: working paper, not submitted, not peer reviewed.
- `docs/v3b_plan.md` (pre-submission additions: d' confound re-analysis, two-group model, unequal-variance G4,
  positioning, external reader) committed for the record and marked paused. None of it has been run: no
  `config/v3b.yml`, no `v3b-prereg` tag, no v3b fits.
- `docs/enhancement_plan_v2.md` committed for the record, marked superseded.
