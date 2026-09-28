# Supplementary Methods

Companion to `report.md`. Everything here is traceable to `config/design.yml`, the code under
`code/`, the tables under `outputs/tables/` and `data/processed/`, and the dated entries in
`docs/design_decisions.md` and `docs/analysis_log.md`.

## S1. Software and sampler

R 4.5.0, `hmetad` 0.2.1, `brms` 2.23.0, package versions locked in `renv.lock`. **All fits were
sampled with `brms`'s default `rstan` backend (rstan/StanHeaders 2.36.0.9000)**, confirmed from
`fit$backend` in saved fits; CmdStan 2.36.0 was installed and smoke-tested but did not run any
model. Details and the reproduction advice are in `docs/computational_environment.md`.

## S2. G1 data-generating process

Diffusion coefficient s = 1 and time step dt = 0.001 s throughout. Parameters shared by all
participants in a cell: drift magnitude v, boundary separation a = 1.5, starting point a/2,
non-decision time t0 = 0.3 s, post-decision duration τ = 0.3 s, readout noise σ_c.

For participant i, trial t:

1. Draw stimulus s ∈ {−1, +1} with probability 0.5 and set the trial drift to δ = s·v.
2. Decision stage: x₀ = a/2, x_{k+1} = x_k + δ·dt + s_d·√dt·ξ_k with ξ_k ~ N(0, 1) (s_d = 1),
   until the first k* with x ≤ 0 or x ≥ a. Response r = +1 if the upper boundary was reached, −1
   otherwise; RT = t0 + k*·dt; correct = 1[r = s].
3. Post-decision stage: the *same* accumulator continues for round(τ/dt) = 300 further steps with
   the same drift and noise and **no absorbing boundary**, so it can move back across the choice
   boundary.
4. q = (x_final − a/2)·r, so positive q is evidence for the response made and negative q is
   post-decisional evidence against it.
5. y = q + ε, ε ~ N(0, σ_c²), independent of ξ.
6. Confidence ∈ {1, …, K} is the within-participant rank-based bin of y (S5).

Stimulus and response are recoded 0/1 for `hmetad`. The continuous q and y are kept in the
simulated data (they are not stored in the compact per-fit records). Reaction time is never used
as evidence magnitude. The simulator is vectorised across trials. A trial that has not reached a
boundary within 50,000 steps triggers a warning and is treated as a non-decision (NA); whether
any occurred during production was not audited (with v ≥ 0.39 and a = 1.5 they should be
vanishingly rare, but that is an expectation, not a check).

## S3. Calibration

**Drift v.** Bisection on v at fixed a = 1.5, t0 = 0.3 s, with N = 100,000 decision-stage trials
per candidate and the *same seed reused across iterations* (common random numbers) so that
empirical d′(v) is smooth. Empirical d′ = Φ⁻¹(hit rate) − Φ⁻¹(false-alarm rate); tolerance ±0.02.
From `outputs/tables/ddm_calibration.csv`:

| Target d′ | v | Empirical d′ (hit/FA) | Empirical d′ (2Φ⁻¹(p_correct)) | Hit | FA | Mean RT (s) | Iterations |
|---|---|---|---|---|---|---|---|
| 0.75 | 0.3881 | 0.7332 | 0.7332 | 0.644 | 0.358 | 0.875 | 9 |
| 1.5 | 0.7972 | 1.4954 | 1.4955 | 0.771 | 0.226 | 0.827 | 10 |

The two d′ estimators agree to within 0.0001, indicating no response bias. Across the production
grid the realised pooled G1 d′ was 0.743 (SD 0.036) and 1.50 (SD 0.038)
(`data/processed/g1_empirical_dprime_check.csv`).

**σ_c.** A pilot at the d′ = 1.5 setting (20,000 trials, one pseudo-participant; SD(q) = 0.581)
generated q once and re-drew only the readout noise for 12 candidate σ_c values from 0.05 to 8
times SD(q) (`outputs/tables/sigma_c_pilot.csv`). Across the sweep, Spearman ρ(q, y) fell from
0.999 to 0.113, Spearman ρ(confidence, correct) fell from 0.319 to 0.037, and there were no tied
values of y. Marginal confidence-category proportions are ≈ 25% by construction under rank
binning, so they cannot show degeneracy and were not used. The three levels were the candidates
whose ρ(confidence, correct) was closest to points 15%, 50% and 85% of the way down the observed
range (`outputs/tables/sigma_c_chosen.csv`): low σ_c = 0.291 (ρ(q, y) 0.883; ρ(conf, correct)
0.287), medium 0.872 (0.530; 0.176), high 2.91 (0.182; 0.062). The same three values were used at
both d′ levels although they were calibrated at d′ = 1.5.

## S4. G0 and G2 generators

Both call `hmetad::sim_metad_participant()` with `sd_dprime = sd_c = sd_M = 0`, `mean_c = 0`,
`mean_M = log_M = −1`, `metac_absolute = TRUE`, `allow_negative_values = FALSE`, confidence-
threshold log-gaps with mean −1 and between-participant SD 0.1 (independent), and
`r_z_c2_0 = r_z_c2_1 = diag(K − 1)`.

**Scale of M (empirically verified; the package help text contradicts it).** `sim_metad(M = )` is
on the natural scale; `sim_metad_participant(mean_M = )` under `allow_negative_values = FALSE` is
already `log_M`; the posterior `Intercept` of `fit_metad()`'s M parameter is `log_M` with no
transform.

**Correlation-matrix bug.** Both generators originally omitted `r_z_c2_0`/`r_z_c2_1`, so they
inherited `hmetad`'s hardcoded `diag(3)` default and worked only at K = 4. This was found when
running K = 6 and fixed (`c99333d`); K = 4 output is unchanged because `diag(3)` was already the
value in effect.

**Gumbel-min (G2).** `hmetad` exports only Gaussian CDFs, so `gumbel_min_lcdf(x, mu)` and
`gumbel_min_lccdf(x, mu)` were written with a fixed scale β = √6/π (unit variance) and location
ν = μ + γβ (γ = Euler–Mascheroni constant) so that the distribution's mean equals μ:
F(x) = 1 − exp(−exp((x − ν)/β)), log F = log1m_exp(−exp((x − ν)/β)),
log(1 − F) = −exp((x − ν)/β). A Stan-side twin using `log1m_exp` is supplied to
`fit_metad()` via `brms::stanvar`. Checked numerically: lcdf and lccdf exponentiate to a valid
complementary pair, and the numerically integrated mean and variance of the CDF equal μ and 1
(on a ±20 grid: means −0.7500, 0.0000, 0.7500 for μ = −0.75, 0, 0.75; variance 1.0000). A first
check on a ±4 grid gave variance 0.92–0.96 because it truncated the long left tail (0.3% of the
mass); widening the grid removed the discrepancy. `hmetad`'s posterior
prediction looks the R functions up by name, so they must be in scope for `epred_draws_metad()`.

## S5. Confidence discretisation

`discretise_confidence()` applies `dplyr::ntile(y, K)` within participant over all of that
participant's trials, giving K equal-frequency bins by rank; exact ties are split by row order
rather than value. It also returns per-participant K−1 empirical-quantile cut-points, counts of
duplicated values and degenerate (equal) cut-points, and category counts. Because bins are
equal-frequency by construction, marginal category counts are uninformative about degeneracy
(the check that matters is the tie count, which was 0 in the pilot). These per-replicate tie and
cut-point diagnostics were **not persisted** in the compact production records (a storage
decision), so they were checked at the pilot stage only.

## S6. Fitted model

Formula (one aggregated row per participant, `aggregate_metad()` called explicitly, then
`fit_metad(aggregate = FALSE)`; the package's own `aggregate = TRUE` forwards `...` to two
functions, which made grouping unreliable):

```text
N ~ 1 + (1 | participant)                      # population log_M and participant deviations
dprime + c ~ 1 + (1 | participant)             # first-order sensitivity and bias
metac2zero1diff + ... + metac2one3diff ~ 1     # confidence-threshold log-gaps, pooled
```

Priors: `normal(0, 1)` on the population `log_M` intercept and on each threshold-gap intercept (all other parameters use brms defaults: flat priors on the d′ and criterion intercepts, `student_t(3, 0, 2.5)` on every participant-level SD; see `outputs/tables/prior_summary.csv`)
(sensitivity sweep: `normal(0, 0.5)`, `normal(0, 2)`). **Prior-class quirk:** a parameter with no
explicit formula takes its prior via `class = "<name>"`, but once it has any explicit formula the
same prior must be given as `class = "Intercept", dpar = "<name>"`; the wrong form fails with
"priors do not correspond to any model parameter" and no hint. The wrapper always uses the second
form. Metacognitive criterion is absolute (`meta_c = c`). Gap intercepts are on the log scale
(generating value −1; the Day-2 baseline fit recovered −0.95 to −1.09).

`aggregate_metad()` layout for K = 4: matrix column `N` has 16 columns, stimulus 0 first then
stimulus 1; within a stimulus, columns 1–4 are response 0 at confidence 4→1 and columns 5–8 are
response 1 at confidence 1→4. This was verified by reproducing hit and false-alarm rates from
the matrix and from trial-level data (identical: 0.668 and 0.372 in the test cell).

## S7. Sampling, diagnostics and the refit rule

4 chains × (1,000 warm-up + 1,000 draws), `adapt_delta` 0.95, max treedepth 12, `cores = 4`
(chain-parallel; this halved the largest-cell fit time from 247 s to 124 s). Diagnostics are
computed on population-level effects (`b_*`) and random-effect SDs (`sd_*`) only, not the
per-participant deviations. Flags: max R-hat ≥ 1.01, minimum bulk or tail ESS < 400, any
divergence, any transition at max treedepth. A flagged fit is refitted once with `adapt_delta`
0.99, treedepth 14 and seed + 1; if still flagged the status is `fail`, and a crash is `error`.
The pre-registered handling rule is in the report (Section 3.4). Reported diagnostics and elapsed
time describe the final attempt only.

## S8. Seeds and grid

`config/grid.csv` has 1,440 rows (G0 240, G1 720, G2 480). `cell_id` indexes each simulated
dataset (1,200 unique); the two G2 fit variants share a `cell_id`, hence the same simulated data.
`sim_seed = seed_base + cell_id` and `fit_seed = seed_base + 1,000,000 + grid_id` with
`seed_base = 20260923`; every random draw inside a generator is wrapped in `withr::with_seed()`.
The three σ_c levels of a G1 cell therefore do **not** share simulation seeds, which is why
ordering accuracy is an independent-replicate comparison paired only by replication index. Rows
were run G1, G0, G2, five at a time (`processx`), resumably (a row is skipped if its result file
exists).

## S9. Metric definitions

- **G0.** Error = posterior mean `log_M` − (−1). Bias = mean error, RMSE = √mean(error²),
  coverage = share of 95% credible intervals containing −1, with Wilson intervals
  (`prop.test(correct = FALSE)`); pooled coverage over all 240 fits, MCSE = √(p(1−p)/n).
- **G1.** Per (N, T, d′) cell, `lm(log_M_median ~ σ_c)` over the 60 fits (3 levels × 20), the
  Spearman correlation of the same pairs, ordering accuracy = share of replication indices with
  low > medium > high, and separation probability P(a > b) = mean over all 20 × 20 replicate pairs.
- **G2.** `loo::loo_compare(list(correct, misspecified))` per dataset; ELPD difference = correct −
  misspecified; SE from the non-reference row; "> 2 SE" means difference > 2·SE. One LOO
  observation is one participant's aggregated count vector. Pareto k > 0.7 is treated as
  unreliable; no moment-matching or exact refit was applied.
- **PPC.** `hmetad::epred_draws_metad()` on the aggregated data, posterior-mean cell probability
  per participant × that participant's stimulus-specific trial count, summed over participants,
  compared with observed counts as proportions conditional on stimulus.
- **Empirical d′.** From pooled hit/false-alarm counts per replicate with proportions clamped to
  [1/(2·max(n₀, n₁)), 1 − that].

## S10. Robustness checks

- **Prior sweep.** One G0 and one G1 dataset (N = 40, T = 200, d′ = 1.5; G1 σ_c medium; rep 1)
  regenerated from the grid row's own `sim_seed` and refitted with the row's own `fit_seed` under
  three priors. Verified byte-identical to the production result at the production prior
  (`grid_id = 901`: posterior mean −0.95794097676536 both times).
- **K = 6.** The same N = 40, T = 200, d′ = 1.5 cell, 5 G0 reps and 5 reps × 3 σ_c levels for G1,
  with the same `sim_seed` and `fit_seed`, compared with the K = 4 results for the same
  `grid_id`s. *Correction (2026-09-28):* only G1 is a re-binning (continuous `y` and responses are
  identical across K). G0 draws discrete confidence directly, so K = 6 is a different generative
  model; the same seed shares only the stimulus sequence (responses agree on 95.1% of trials, and
  the K = 6 × K = 4 confidence table is not block-structured). The G0 rows are retained but
  flagged `valid_rebinning = FALSE` and support no inference about binning.

## S11. Stored outputs

Every row keeps a compact record (status, escalation flag, warnings, diagnostics, posterior
draws of `b_*`/`sd_*`, aggregated counts, grid metadata; G2 rows add the `loo` object and a per-
cell posterior-predictive summary). The full `brmsfit` is kept only for replications 1–2. Tracked
summaries are in `data/processed/`; per-fit files (`data/interim/*.qs2`) are git-ignored.

## S12. Deviations from the original protocol

| Change | Why |
|---|---|
| `qs2` instead of `qs` | `qs` is archived on CRAN for R 4.5 |
| Explicit `aggregate_metad()` then `fit_metad(aggregate = FALSE)` | `fit_metad(aggregate = TRUE)` dots forwarding is ambiguous for grouping columns |
| Hierarchy on `log_M`, d′, c; thresholds pooled | bounds model size; both switches are arguments of the wrapper |
| 20 replications per cell instead of 30 | measured throughput ≈ 55 fits/hour made 30 a 41+ hour run; RQ1 is ordinal; coverage is pooled |
| Compact records, full fit for reps 1–2 only | storage |
| Chain-parallel sampling and concurrent grid dispatch | ~2× per-fit speed-up; ~5 fits at once |
| `run_one_cell.R` takes one `grid_id` (rep id is a grid column) | fewer arguments, same information |
| Run order G1, G0, G2 | G1 is the primary-question generator |
| Confidence-bin sensitivity is K = 6 on 20 fits | protocol asks for a small representative subset |

## S13. Errata and corrections found during the project

Each is recorded with its date in `docs/analysis_log.md`.

1. **Backend misdescribed.** Documents said CmdStan; fits used `rstan` (S1). Corrected 2026-09-25.
2. **Calibration table.** Hit/FA/RT cells and one d′ in `design_decisions.md` were entered without
   the CSV in view and were wrong; corrected to the values in S3.
3. **Bias range misattributed.** A G2-correct range was quoted as G0's; verified values: G0
   −0.177 to −0.025, G2-correct −0.092 to −0.007, G2-misspecified +0.064 to +0.195.
4. **K-generic generators** (S4) and **a hardcoded interpretation string** in the K = 6
   robustness table that contradicted the computed result; both fixed before results were used.
5. **PPC claim scope.** The confidence-level-4 pattern in the misspecified fit's discrepancies is
   one replicate per fit and is reported as suggestive.
