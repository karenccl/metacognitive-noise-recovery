# Design Decisions

Design specification for this simulation study: the locked decisions below were fixed before any
production fitting. Record any justified deviation below with a date; do not silently alter
the core scientific question.

## Status

- [x] Absolute vs. relative type-2 criteria decision, and why
- [x] Aggregation route / expected `hmetad` input schema
- [x] Exact primary/secondary outcomes
- [x] Grid, seed scheme, sampling configuration, diagnostic/refit policy
- [x] Definition of what counts as a deviation
- [x] G1 DGP written as equations/pseudocode
- [x] DDM-to-empirical-d′ calibration plan

## 2026-09-22 — Initial scaffold

Repository structure created. No scientific decisions locked yet.

## 2026-09-23 — Deviation: qs → qs2

The initial package list specified `qs` for atomic per-cell result storage. `qs` is archived on CRAN
and unavailable for R 4.5.0; installed `qs2` (same author, maintained successor) instead.
Interim result files now use `qs2::qs_save()`/`qs2::qs_read()` and the `.qs2` extension in
place of `.qs`. Purely a serialization-format substitution; no effect on the scientific design,
grid, or estimands. See `docs/computational_environment.md` and `docs/analysis_log.md` for
details.

## Locked decisions

- **Primary estimand:** group-level or condition-level posterior `log_M` from `hmetad`.
- **`log_M` interpretation:** M = exp(log_M) = meta-d′ / d′; log_M = -1 implies M ≈ 0.368.
- **G1 ground truth:** a predefined post-decisional confidence-readout noise parameter σ_c.
  Primary target is ordinal recovery, not numerical recovery of σ_c by log_M.
- **Confidence scale:** K = 4 ordinal categories via a prespecified rank-based, within-subject
  discretisation rule, implemented once in `discretise_confidence()`
  ([code/01_simulate/discretise_confidence.R](../code/01_simulate/discretise_confidence.R)).
- **Primary G1 criterion:** probability of correct ordering and estimated monotonic slope of
  `log_M` over σ_c, with Monte Carlo uncertainty.
- **Secondary G1 criterion:** posterior predictive checks of joint stimulus × response ×
  confidence counts.
- **Primary analysis grid:** N ∈ {20, 40}; T ∈ {100, 200, 400}; d′ target ∈ {0.75, 1.5};
  σ_c ∈ {low, medium, high} (calibrated); replications target 30/cell, minimum 15.
- **Random-number policy:** every run has an explicit, deterministic seed derived from
  generator, grid-cell ID, and replication ID.
- **Bayesian fit policy:** fixed sampling settings, diagnostic thresholds, and refit/escalation
  policy decided before batch execution.
- **Stop rule:** release the reproducible state at the end of Day 6; unfinished optional
  analyses become limitations, not additional unplanned work.

## 2026-09-23 — hmetad API notes (from package help; no vignettes bundled in 0.2.1)

`hmetad` 0.2.1 (metacoglab r-universe) is a `brms`-based reimplementation of the meta-d′ model,
not the classic Fleming JAGS/Stan HMeta-d toolbox. The functions used in this study (`sim_metad`, `fit_metad`, `aggregate_metad`, `stanvars_metad`,
`epred_draws_metad`, `joint_probabilities`, `type2_probabilities`) are all present in this
version. Key facts established empirically (see
`docs/analysis_log.md` for the verification script/output):

- **Scale of `M`/`log_M` differs by function — this is the single most important gotcha:**
  - `sim_metad(M = ...)`: `M` is on the **natural scale** (M itself). To generate data with a
    target `log_M`, pass `M = exp(log_M_target)`. Verified: `sim_metad(M = exp(-1))` returns
    an `M` column of exactly `0.3679`.
  - `sim_metad_participant(mean_M = ..., allow_negative_values = FALSE)` (`FALSE` is the
    documented default): `mean_M` is on the **log scale already** — pass `log_M_target`
    directly. Verified: `mean_M = -1` under `allow_negative_values = FALSE` produces an `M`
    column of `exp(-1) = 0.3679` (i.e. the function exponentiates internally). Under
    `allow_negative_values = TRUE`, `mean_M` is used as-is on the natural/identity scale
    (verified: `mean_M = -1` → `M` column of exactly `-1`). The `?sim_metad_participant` help
    text has the `TRUE`/`FALSE` description swapped relative to the actual default argument
    value — trust the empirical check, not the prose.
  - `fit_metad(..., allow_negative_values = FALSE)` (default): the posterior `Intercept` for
    the `M` distributional parameter **is `log_M` directly**, no further transform needed.
    Verified: fitting `sim_metad(N_trials = 2000, dprime = 1.5, M = exp(-1))` recovered a
    posterior `Intercept` of ≈ −1.06 (95% CI [−1.52, −0.72]), correctly bracketing the
    generating `log_M = −1`.
  - **Consequence for code:** `simulate_g0.R` and `simulate_g2_gumbel.R` must convert any
    config-specified `log_M` target to `M = exp(log_M)` before calling `sim_metad()`/
    `sim_metad_condition()`, or pass `log_M` straight through as `mean_M` if using
    `sim_metad_participant()`/`sim_metad_participant_condition()` with
    `allow_negative_values = FALSE`. `extract_fit_summary.R` reads the `M` `Intercept` row as
    `log_M` with no transform.

- **Type-2 criterion parameterization (`metac_absolute`):** `fit_metad()`/`stanvars_metad()`/
  `metad()` default to `metac_absolute = TRUE`, i.e. `meta_c = c` (the type-2 criterion is
  fixed equal to the type-1 criterion — the standard meta-d′ assumption, e.g. Maniscalco &
  Lau). The alternative (`metac_absolute = FALSE`, `meta_c = M * c`) re-expresses the type-2
  criterion *relative* to `c`/`dprime` and is not needed for this project.
  **Locked decision: use `metac_absolute = TRUE` (the package default) throughout G0/G1/G2,**
  matching the standard model definition the design's `log_M` interpretation assumes.

- **Aggregation route:** `fit_metad(..., aggregate = TRUE)` (default) accepts one-row-per-trial
  data with `stimulus`, `response`, `confidence` (+ any grouping columns in the formula) and
  internally calls `aggregate_metad()` to build the multinomial sufficient-statistic
  representation (`N_0`, `N_1`, and a `N_0_1..N_0_K, N_1_1..N_1_K`-style count matrix — `4*K`
  cells per group). **Initial decision (SUPERSEDED, see "Aggregation route revised" in the 2026-09-23 Day 2 fit_one_hmetad()
  entry below):** all fits use `aggregate = TRUE` on trial-level input. In the final pipeline
  `fit_one_hmetad()` calls `aggregate_metad()` itself and fits with `aggregate = FALSE`. This is precisely why the likelihood is
  aggregated-count-based and why LOO must be interpreted at the subject/cell level, not the
  trial level.

- **`K`** is auto-inferred by `aggregate_metad()`/`fit_metad()` from `max(confidence)` if not
  passed explicitly; scripts should pass `K` explicitly (from `config/design.yml`) rather than
  rely on inference, so a partially-degenerate discretisation (e.g. a subject never reaching
  the top category) can't silently change `K` for one cell.

- **Setting priors:** `metac2_parameters(K, response = "both")` returns the `K-1` threshold-gap
  parameter names for use with `brms::set_prior()`, per the package's own documented example:
  `set_prior("normal(0, 1)", class = "b", dpar = metac2_parameters(K = 4))`.

## 2026-09-23 — Locked fitting/prior policy

- **Type-2 criterion:** `metac_absolute = TRUE` (see above).
- **Aggregation:** `aggregate = TRUE` on trial-level data (see above).
- **Primary log_M prior (G0/G1/G2 production fits):** `normal(0, 1)` on the `M` dpar
  Intercept — the middle of the three values used in the Day-4 prior-sensitivity sweep
  (`normal(0, 0.5)`, `normal(0, 1)`, `normal(0, 2)`), so the sensitivity analysis brackets the
  production choice rather than being unrelated to it.
- **Confidence-threshold-gap prior:** `normal(0, 1)` on all `metac2_parameters(K)` coefficients
  (per the package's documented example), for both G0/G1 (`distribution = "normal"`, default)
  and G2's correctly-specified fit (`distribution = "gumbel_min"`); G2's Gaussian-misspecified
  fit reuses the same priors as G0/G1 since it *is* the G0/G1 model family.
- **G2 distribution:** `gumbel_min`, per the design and `stanvars_metad()`'s own
  worked example (`stanvars_metad(4, distribution = "gumbel_min")`).

## 2026-09-23 — G0/G2 generator implementation and Gumbel-min parameterisation

`simulate_g0()` and `simulate_g2_gumbel()` (`code/01_simulate/simulate_g0.R`,
`code/01_simulate/simulate_g2_gumbel.R`) both use `hmetad::sim_metad_participant()` with
`sd_dprime = sd_M = sd_c = 0` (no between-subject variability in the parameters that matter for
the known-truth check — a small default between-subject spread is kept on the confidence
thresholds, `sd_z_c2_{0,1} = 0.1`, since zero threshold variability would be an unrealistic
degenerate case and isn't needed for `log_M` to be exact). `log_M` is passed straight through as
`mean_M` under `allow_negative_values = FALSE`, per the hmetad API notes above. Verified: for
`log_M = -1`, the `M` column is exactly `exp(-1) = 0.3679` for every simulated row, and a quick
`fit_metad()` recovers a posterior `Intercept` of ≈ −1.02 (95% CI [−1.31, −0.81]).

**`hmetad` exports no Gumbel-min `lcdf`/`lccdf`** (only `normal_lcdf`/`normal_lccdf`, both with
signature `(x, mu)` and an implicit fixed unit scale). `simulate_g2_gumbel.R` defines its own
pair using the standard Gumbel-min CDF `F(x) = 1 - exp(-exp((x-nu)/beta))`, with two locked
implementation choices to keep it a drop-in, comparable analog to the normal case per the
package's "parameter-free" requirement:

- **Fixed scale `beta = sqrt(6)/pi`**, giving unit variance (matching the normal's implicit
  `sd = 1`).
- **Location shifted so the distribution's mean equals the input `mu` exactly**:
  `nu = mu + gamma * beta` (`gamma` = Euler–Mascheroni constant), since the raw Gumbel-min
  location parameter is *not* its mean (`mean = nu - gamma*beta`) and `mu` needs to play the
  same "mean-of-signal-distribution" role that `dprime`/`meta_c` play in the Gaussian case.

Verified numerically: `exp(lcdf(x,mu)) + exp(lccdf(x,mu)) == 1` for all tested `x`; numerically
estimated mean/variance from the CDF recover `mu`/`1` to within Monte Carlo/grid error; `sim_metad()`
with these functions produces no `NA`s and shows accuracy increasing with `dprime` as expected
(hit rate 0.70→0.81 going from `dprime=0.75` to `1.5`, both non-degenerate). This is a
documented, locked distributional choice, not a claim that meta-d′/dprime on the Gumbel-min
scale is numerically equivalent to the Gaussian scale (the scale caveat still
applies to any cross-distribution parameter comparison).

**Day 2 dependency, not yet implemented:** fitting the correctly-specified G2 model requires
matching **Stan-side** `gumbel_min_lcdf`/`gumbel_min_lccdf` function definitions (via an extra
`brms::stanvar(scode = ..., block = "functions")` passed alongside `stanvars_metad(K,
distribution = "gumbel_min")` to `fit_metad()`), using the identical `nu`/`beta`
parameterisation as the R functions above. `stanvars_metad()`'s own generated code already
*calls* `gumbel_min_lcdf`/`gumbel_min_lccdf` (confirmed by inspecting its Stan code) but does not
define them — this is exactly what its documentation means by "you must additionally provide two
functions to Stan." Needed in `code/02_fit/fit_hmetad.R`.

## 2026-09-23 — G1 DGP specification

Written before implementation, per the Day-1 gate. Diffusion coefficient fixed at `s = 1`
throughout (standard DDM convention; `v`/`a` are expressed in units of `s`). Time step
`dt = 0.001 s` (1 ms) for Euler–Maruyama simulation of the accumulator.

**Parameters (per participant, fixed across trials within a cell unless noted):**
`v` (drift magnitude), `a` (boundary separation), `z = a/2` (unbiased starting point),
`t0` (nondecision time), `tau` (fixed post-decision accumulation duration), `σ_c` (readout
noise SD, the G1 ground truth manipulated across the low/medium/high grid cells).

**Per-trial generative process, for participant *i*, trial *t*:**

1. Draw stimulus `s_it ∈ {−1, +1}` with `P(s_it = +1) = 0.5`.
2. Set trial drift `δ_it = s_it · v` (drift toward the `+1`-consistent boundary `a` when
   `s_it = +1`, toward boundary `0` when `s_it = −1`).
3. Simulate the pre-decision accumulator as a discrete-time approximation to the DDM:
   `x_0 = z = a/2`; `x_{k+1} = x_k + δ_it · dt + sqrt(dt) · ξ_k`, `ξ_k ~ N(0, 1)`, until
   `x_k` first crosses `0` or `a` at step `k*`. Decision time `DT_it = k* · dt`;
   `rt_it = t0 + DT_it`. Type-1 response `r_it = +1` if the upper boundary `a` was hit,
   `r_it = −1` if the lower boundary `0` was hit. `correct_it = 1[r_it = s_it]`.
4. **Post-decisional accumulation (correlated with pre-decision evidence — the same
   accumulator continues, it does not restart):** continue the identical accumulator update
   (`δ_it`, same noise process, same `dt`) for a further fixed duration `tau`, i.e.
   `⌊tau / dt⌋` additional steps, *without* an absorbing boundary (the accumulator can wander
   arbitrarily, including back across the decision boundary — this is what allows
   post-decisional evidence to disagree with the initial choice). Let `x_final` be the
   accumulator value after these additional steps.
5. Define the **decision-consistent confidence-relevant latent quantity**:
   `q_it = (x_final − a/2) · r_it` (using `r_it ∈ {−1, +1}`). This flips sign for `r_it = −1`
   responses so that, for both response types, larger `q_it` means more accumulated evidence
   *in favor of the response actually made* (i.e., higher intended confidence), and `q_it`
   can go negative (post-decisional evidence against the choice made — a "changed my mind"
   region), which is an intended feature of the mechanism, not a bug.
6. **Noisy confidence evidence (design equation):** `y_it = q_it + ε_it`, `ε_it ~ N(0, σ_c²)`.
   `σ_c` is independent of trial/participant noise draws (uncorrelated with `ξ_k`).
7. Convert `y_it` to `confidence_it ∈ {1, …, K}` (`K = 4`) via the locked
   `discretise_confidence()` rank-based within-subject rule, applied over all of a subject's
   trials at once (not per-cell), using the **continuous** `y_it`, not `q_it` or accuracy.

**Retained columns (design requirement — keep both `q` and `y` even though only binned
`confidence` goes to `hmetad`):** `participant`, `trial`, `stimulus` (recoded `0`/`1` for
`hmetad`), `response` (recoded `0`/`1`), `correct`, `rt`, `q`, `y`, `confidence`, plus generator
metadata columns `v`, `a`, `t0`, `tau`, `sigma_c`, `seed`.

**Explicitly avoided:** using `a · RT` (or any function of RT alone) as a stand-in for
terminal/post-decisional evidence magnitude (the named fatal mistake) — `q`
above is always read directly off the simulated accumulator trajectory, never derived from RT.

## 2026-09-23 — DDM-to-empirical-d′ and σ_c calibration plan

**Drift/boundary → target `d′` (`{0.75, 1.5}`), to run in `code/01_simulate/validate_generators.R`
before the primary grid, output to `outputs/tables/ddm_calibration.csv`:**

1. Fix `a` and `t0` at documented starting values (`a = 1.5`, `t0 = 0.3 s`, revisit only if
   step 3 cannot reach both target `d′` levels within plausible RTs); vary only `v`.
2. For each candidate `v`, simulate `N = 100,000` trials (step 3 of the DGP above, decision
   stage only — no post-decision stage needed for calibration) at `50/50` stimulus.
3. Compute empirical hit rate `H = P(r = +1 ∣ s = +1)` and false-alarm rate
   `F = P(r = +1 ∣ s = −1)`; empirical `d′ = Φ⁻¹(H) − Φ⁻¹(F)` (the general SDT formula; the
   symmetric drift/boundary design should give `H ≈ 1 − F`, so this should agree with the
   simplified `d′ = 2·Φ⁻¹(p_correct)` as a cross-check — report both, flag if they disagree
   materially since that would indicate a bias/asymmetry bug).
4. Adjust `v` (bisection on `d′`) until empirical `d′` is within a prespecified tolerance
   (`±0.02`) of each target. Record `v`, resulting `d′`, `H`, `F`, mean RT, and `N` per target
   in `outputs/tables/ddm_calibration.csv`.
5. If both targets cannot be reached with a shared `a`/`t0` at plausible mean RTs
   (`< 2 s`), allow `a`/`t0` to vary by target level and document why in this file (a
   deviation, but an anticipated and justified one — see the design).

**σ_c low/medium/high pilot, before the primary grid:**

Because the `K = 4` discretisation is a rank-based within-subject quantile rule, **marginal confidence-category occupancy will be ≈25% per category for every
σ_c by construction** — that is not a valid pilot diagnostic here (this is exactly the
degeneracy the design warns about). Instead:

1. At one calibrated DDM setting (`d′ = 1.5`, one large pseudo-subject, `T = 20,000`), sweep a
   grid of candidate `σ_c` values (e.g. informed by the empirical SD of `q` from step 2 of the
   drift calibration, spanning roughly `0.1×SD(q)` to `3×SD(q)`).
2. For each candidate, compute: (a) Spearman `ρ(q, y)` — should fall from ≈1 toward 0 as `σ_c`
   increases; (b) the point-biserial/Spearman association between `y` (or binned `confidence`)
   and `correct` — the substantively meaningful "is confidence still informative" diagnostic,
   since raw category counts will not show degeneracy; (c) proportion of tied `y` values before
   binning (should be ≈0 given continuous Gaussian noise added to continuous `q`; a nonzero
   rate would indicate a simulation bug, e.g. duplicated trials or an degenerate `q`).
3. Choose "low/medium/high" as three `σ_c` values spanning a clearly distinguishable range of
   the confidence–accuracy association from (b) — not evenly-spaced arbitrary numbers. Record
   the actual chosen values and the full pilot sweep table (do not just label them low/medium/
   high without justification, per the design).
4. Save the pilot sweep and final chosen values into `docs/design_decisions.md` (update this
   section) and `config/design.yml` once run.

## 2026-09-23 — DDM calibration and σ_c pilot results

Run via `code/01_simulate/validate_generators.R` (seed base `20260923` from
`config/design.yml`). Full tables in `outputs/tables/ddm_calibration.csv`,
`outputs/tables/sigma_c_pilot.csv`, `outputs/tables/sigma_c_chosen.csv`.

**Drift calibration** (bisection, `N = 100,000` trials/target, `a = 1.5`, `t0 = 0.3s`, shared
seed across bisection iterations — common random numbers, so empirical `d′(v)` is smooth and
bisection is stable):

| `d′` target | `v` | empirical `d′` (H/FA formula) | empirical `d′` (2·Φ⁻¹(p_correct)) | hit rate | FA rate | mean RT |
|---|---|---|---|---|---|---|
| 0.75 | 0.388 | 0.7332 | 0.7332 | 0.644 | 0.358 | 0.875 s |
| 1.5 | 0.797 | 1.4954 | 1.4955 | 0.771 | 0.226 | 0.827 s |

*(Corrected 2026-09-25 from `outputs/tables/ddm_calibration.csv`; the hit/FA/RT cells and the
`1.500` in an earlier version of this table had been entered without checking against the CSV and
were wrong. See `docs/analysis_log.md`.)*

Both `d′` targets reached within the ±0.02 tolerance (errors 0.017 and 0.005). The two empirical
`d′` formulas agree to within 0.0001 for both targets, confirming no detectable response bias —
a shared `a = 1.5, t0 = 0.3s` works for both target levels, so no per-target `a`/`t0`
deviation was needed.

**σ_c pilot** (`N = 20,000` trials, one pseudo-subject, calibrated `v = 0.797` for `d′ = 1.5`,
`a = 1.5`, `tau = 0.3s`; `SD(q) = 0.5811`). Confirmed the section-1.4 concern empirically: raw
confidence-category counts stay at ~25%/category across the entire sweep (by construction of
the rank-based binning) and were not usable as a diagnostic; `cor(confidence, correct)`
(Spearman) was used instead and decreases smoothly and monotonically across all 12 candidate
`σ_c` values (0.999→0.113 for `cor(q,y)`; 0.319→0.037 for `cor(confidence, correct)`); no tied
`y` values anywhere in the sweep.

**Chosen low/medium/high** (closest matches to 3 targets spanning the observed
`cor(confidence, correct)` range, at 85%/50%/15% of that range from the ceiling — see
`validate_generators.R` for the exact selection rule):

| Level | `σ_c` | `σ_c` / SD(q) | `cor(q, y)` | `cor(confidence, correct)` |
|---|---|---|---|---|
| low | 0.291 | 0.5 | 0.883 | 0.287 |
| medium | 0.872 | 1.5 | 0.530 | 0.176 |
| high | 2.91 | 5.0 | 0.182 | 0.062 |

These are a clearly distinguishable, non-arbitrary spread (not evenly-spaced numbers picked
without justification) and are now locked in `config/design.yml` (`ddm.v_by_dprime_target`,
`ddm.sigma_c_values`). **Note:** these calibration/pilot runs used the decision+post-decision
stages only (no readout-noise-dependent quantity affects `q`), so the same `q` realisation was
reused across the whole `σ_c` sweep — an intentional, documented variance-reduction choice, not
a shortcut that changes what's being measured.

## 2026-09-23 — Day 2: fit_one_hmetad() implementation and hierarchical model structure

`code/02_fit/fit_hmetad.R` implements `fit_one_hmetad()` plus two internal helpers,
`.build_metad_formula()` and `.build_metad_priors()`. Two more `brms`/`hmetad` gotchas were
found empirically while building this (neither documented in the package's help pages):

**1. Aggregation route revised.** `fit_metad(..., aggregate = TRUE)` forwards its own `...` dots
to both `brm()` (sampler args) and, per its documented approximate equivalence, to
`aggregate_metad()` (grouping columns) — the same dots serving two purposes is an unreliable
way to pass a grouping variable. This wrapper instead calls
`hmetad::aggregate_metad(data, <group>, K)` itself and fits on the pre-aggregated data with
`fit_metad(..., aggregate = FALSE)`, which the package's own documentation explicitly endorses
("may often be easier to use the more explicit version"). `config/design.yml`'s
`fitting.aggregate` is now `false` to reflect this (was `true`).

**2. Prior-class registration depends on whether a dpar has an explicit formula.** When a dpar
(`dprime`, `c`, or a `metac2_parameters()` gap) is left at the family's implicit default (no
formula given to `bf()`), its prior is set with the bare form `class = "<dpar_name>"`. As soon
as that dpar is given *any* explicit formula — even just `~1`, let alone `~1 + (1|participant)`
— brms switches to registering it as a standard distributional parameter, and the correct prior
form becomes `class = "Intercept", dpar = "<dpar_name>"`. Using the wrong form raises "priors do
not correspond to any model parameter" with no hint about which form is expected. Verified via
`brms::get_prior()` on both formula styles side by side.
`.build_metad_priors()` always uses the `dpar=` form because `.build_metad_formula()` always
gives every dpar (mu/`N`, `dprime`+`c` combined, and the threshold gaps combined) an explicit
formula — combining multiple dpar names on one formula's LHS with `+` (`dprime + c ~ ...`),
matching the syntax in `fit_metad()`'s own condition-level-effects example, since separate
individual formulas per dpar were tested and do NOT reliably register (same symptom).

**Hierarchical model structure (locked, `config/design.yml` `fitting:`):** `(1|participant)` on
the primary `mu`/log_M parameter (always) and on `dprime`+`c` (`hierarchical_dprime_c = TRUE`,
matching classic hierarchical HMeta-d practice of letting individual sensitivity/bias vary).
Confidence-threshold gaps are pooled (not hierarchical) by default
(`hierarchical_thresholds = FALSE`) to bound model complexity/runtime — both are exposed as
`fit_one_hmetad()` arguments so the Day 2 compute benchmark can revisit this if the full
hierarchical-thresholds version is affordable.

**Verified on a small/fast configuration** (G0 data, `N=20, T=100`, 2 chains × 375 post-warmup
draws, `adapt_delta=0.95`): 0 divergent transitions (3 divergences appeared at brms's own
default `adapt_delta=0.8`, confirming the locked `0.95` matters), all population-level
parameters recovered near their generating values (`log_M` Intercept ≈ −1.08 vs. true −1,
`dprime` ≈ 1.53 vs. true 1.5, `c` ≈ 0.004 vs. true 0), and `extract_fit_summary()` correctly
flagged `status = "refit"` due to one random-effect SD parameter's ESS falling short of 400 —
expected at this deliberately small smoke-test sample size, not the production configuration.
Also verified `fit_one_hmetad()`'s input validation rejects out-of-range confidence codes,
missing columns, and non-0/1 stimulus/response coding before any Stan compilation is attempted.

`extract_fit_summary()` (`code/02_fit/extract_fit_summary.R`) restricts its focal-parameter
R-hat/ESS check to population-level effects (`^b_`) and random-effect SDs (`^sd_`), explicitly
excluding the numerous per-participant deviation terms (`r_participant[...]`) — consistent with
the design's "focal population parameters" wording. It classifies `pass`/`refit` only;
`fail` (an escalated refit that still doesn't pass) is a decision for the not-yet-implemented
`run_one_cell.R`, which owns the retry/escalation policy and thus the retry history a single
call to `extract_fit_summary()` can't see.

## 2026-09-23 — Day 2 midday: compute benchmark and replication count

per the design (Day 2 midday). Benchmarked `fit_one_hmetad()` at production sampling
settings across the N/T corners of the grid (G0 data, `dprime_target=1.5`, `log_M=-1`):

| N | T | elapsed (s), `cores=1` (default before today) |
|---|---|---|
| 20 | 100 | 195.1 |
| 20 | 400 | 140.7 |
| 40 | 100 | 243.6 |
| 40 | 400 | 247.1 |

Confirms the expected pattern: fit cost tracks N (hierarchical units after aggregation), not T
(aggregation collapses each participant's trials to one count row before fitting) — T's small
effect above is noise/sampler-efficiency variation, not a real cost driver.

**Found and fixed a real inefficiency while benchmarking:** `fit_one_hmetad()` was not passing
`cores` to `fit_metad()`/`brm()`, so its 4 chains ran on a single core by default. Added a
`cores` argument (default `= chains`) to `fit_one_hmetad()` and `fit_hmetad.R`'s `fit_metad()`
call. Re-benchmarking the largest cell (N=40, T=400) with `cores=4`: **247.1s → 123.9s**
(~2x speedup), identical clean diagnostics (max R-hat 1.004, 0 divergences). This is a pure
efficiency fix with no effect on the model or estimand.

**Projected total grid cost** (72 unique fit-cells/replication: 12 G0 + 36 G1 + 24 G2
[12 cells × 2 fit variants]), using the `cores=4` numbers, one fit at a time: ≈2.07 hours per
full pass over the grid, ≈62 hours (2.6 days) at the target 30 replications/cell if run strictly
sequentially.

**Decision (user consulted given real machine-time consequences):** add simple concurrent batch
dispatch rather than reduce replications. `code/02_fit/run_grid.R` was rewritten to launch up to
`config/design.yml`'s `execution.max_concurrent_fits` (`5`, sized as
`floor((22 cores - 2 headroom) / 4 cores-per-fit)` for the current machine) `run_one_cell.R`
subprocesses at once via `processx`, polling and backfilling as each finishes. This keeps the
full pre-specified **30 replications/cell** (no Monte Carlo precision compromise) at a
projected **~12-13 hours** total wall time — feasible as a single unattended run. Verified the
concurrency logic on a 6-row/max-concurrent-3 smoke grid: pool correctly held at 3, backfilled
as jobs finished, all 6 completed with correct exit statuses and no crashes.

`config/00_setup/02_create_grid.R` was run to generate the real `config/grid.csv`: 2160 total
fit rows over 1800 unique simulated-dataset cells (360 G0 + 1080 G1 + 360 G2-cell-reps, the
latter split into 360 "correct" + 360 "misspecified" fit rows), matching this projection exactly.

**Not yet launched:** the actual full production grid run. `config/grid.csv` is generated and
ready; `make g0` / `make g1` / `make g2` (or `Rscript code/02_fit/run_grid.R`) will run it.

## 2026-09-23 — G2 Gumbel-min Stan functions implemented

Closes the dependency flagged when `simulate_g2_gumbel.R` was written. Added `gumbel_min_stanvars()`
to `code/01_simulate/simulate_g2_gumbel.R`: a `brms::stanvar(block = "functions")` defining
Stan-side `gumbel_min_lcdf`/`gumbel_min_lccdf`, numerically identical to the R-side functions in
the same file (same `beta = sqrt(6)/pi`, same `nu = mu + euler_gamma*beta` mean-centering; Stan's
built-in `log1m_exp()` computes `log(1 - exp(-exp(z)))` directly and stably, matching
`log1p(-exp(-exp(z)))` on the R side). `code/02_fit/run_one_cell.R` now passes
`gumbel_min_stanvars()` as `extra_stanvars` whenever `generator == "g2"` and
`fit_variant == "correct"`.

**Verified end-to-end** on G2-generated data (N=20, T=100, `dprime_target=1.5`, `log_M=-1`,
reduced settings: 2 chains × 400 draws for speed): the Stan program now compiles and samples
successfully (previously errored at compile time with "undeclared identifier
gumbel_min_lccdf" — see the Day-2-midday smoke test above). Recovered `log_M` Intercept ≈ −0.80
(95% CI [−1.05, −0.58], true −1 near the edge of the interval — expected at this reduced
2-chain/400-draw test size, not the production configuration). `status="refit"` (R-hat 1.022,
min ESS 344/404) at this reduced size is also expected; production settings (4 chains,
1000+1000 warmup/sampling) should resolve it, to be confirmed by the actual grid run.

Added a fast (no-MCMC, `empty=TRUE`) regression test to `tests/test_data_format.R` checking that
`gumbel_min_stanvars()` produces buildable Stan code containing the expected function name, so a
future accidental regression in the Stan code string would be caught immediately rather than
only during a full grid run.

**Day 2 gap now closed.** All three generators (G0, G1, G2 correct + misspecified) have a
working, tested fitting path. Ready to launch the full production grid.

## 2026-09-23 — Production run stopped and revised before relaunch

The first full-grid launch (2160 rows, 30 reps/cell) was stopped manually after producing 16
results, to make several changes before committing real compute to it. Each change below is a
locked decision (updates the "locked decisions" list where relevant); rationale is recorded here
per the reproducibility-log requirement.

### Replications: 30 → 20

Measured throughput at 5-way concurrency was ~52 fits/hour (thermal-throttled below the raw
~124s/fit `cores=4` benchmark, which implies a theoretical ~145 fits/hour at 5-way concurrency),
making the 30-rep grid a 41+ hour run rather than the ~12-13 hour projection. Revised
`config/design.yml`'s `grid.replications.target` to **20**.

**Rationale:** RQ1 (the primary question) is an ordinal/monotonicity question — probability
of correct `log_M` ordering across `σ_c` and the sign/direction of the `log_M`-on-`σ_c` slope —
not a point-estimate-precision question. At 20 replications, Monte Carlo SE of a bias estimate is
≈0.04 (on the `log_M` scale), adequate for this purpose. Per-cell 95% CI coverage (a G0 secondary
metric) is imprecise at *any* feasible replication count for a single cell (a 20-replication
binomial proportion has a wide CI on its own coverage rate) — this was true even at 30 reps and is
not meaningfully worse at 20. The plan is therefore to **pool coverage across all G0 cells**
(360 replications total after pooling, giving coverage MCSE ≈1.3%) and report pooled coverage
with its MCSE, rather than claim precision on any single cell's coverage. This does not weaken
the primary (G1 ordinal) claim, which was never coverage-based. `grid.replications.minimum: 15`
(the pre-specified floor) is unchanged and not needed here since 20 was reached directly, not via
further escalation.

### Pre-specified failed-fit handling rule (before seeing any real results)

To avoid the appearance (or reality) of post-hoc rationalization once the grid finishes, the
following is locked **now**, before any production-scale results exist:

- **Primary analysis:** includes every fit with `status` `"pass"` **or** `"fail"` (i.e. every
  attempted fit that produced a posterior at all, whether or not it cleared diagnostic
  thresholds after escalation). Fits are **flagged** by their status in all primary tables/figures
  — never silently pooled with passes as if equivalent — per the design's "never
  suppress failed fits."
- **Sensitivity analysis:** re-runs the primary metrics on **pass-only** fits, to check whether
  conclusions depend on including diagnostically-flagged fits.
- **`status = "error"` rows** (simulation or Stan compile/runtime errors, not merely poor
  diagnostics) are excluded from both the primary and sensitivity *parameter-estimate* analyses
  (there is no posterior to include) and are instead **reported as convergence/computational
  failures in RQ3** (the design's understanding-check framing: "a high convergence-failure rate
  signals computational instability... and must be reported"), i.e. counted in the failure-rate
  denominator and tabulated by condition, consistent with the already-locked "Fail" row of the
  status table in the design.

### Compact output format (storage)

`run_one_cell.R` now saves a **compact record** per grid row instead of the full `brmsfit`:
`status`, `diagnostics` (already compact — R-hat/ESS table for focal `b_*`/`sd_*` parameters
only, from `extract_fit_summary()`), `escalated`, `warnings`, `error_message`, all grid metadata,
the aggregated observed counts (`agg`, from `hmetad::aggregate_metad()`), and posterior **draws
for `b_*`/`sd_*` parameters only** (`extract_b_sd_draws()`, mirroring `extract_fit_summary()`'s
own focal-parameter selection so the two never disagree about what counts as "focal"). This is
still everything a group-level/condition-level analysis needs (the design's primary estimand is
population-level `log_M`, not any individual participant's random-effect deviation).

The **full `brmsfit`** is additionally kept only when `rep_id <= config's
execution.keep_full_fit_max_rep_id` (locked at **2**) — enough to spot-check/debug a fit
interactively (e.g. re-run `pp_check()`-style diagnostics by hand) without keeping ~2000 full Stan
fit objects on disk.

For **G2 rows only** (both fit variants — G2's whole purpose is a correct-vs-misspecified
comparison, so both need the same diagnostics, not just "correct"), also computes and saves:
- `loo` — the full `brms::loo()` object (confirmed working out-of-the-box on these custom-family
  fits: `log_lik()` returns a `draws x n_participants` matrix, i.e. one LOO observation per
  participant, consistent with the already-documented "aggregated subject-level cell counts"
  LOO-unit caveat). Needed for the Day-4/Day-5 G2 LOO/ELPD comparison.
- `epred_summary` — a **per-cell summary** (mean/median/95% interval) of
  `hmetad::epred_draws_metad()`, grouped by participant × stimulus × response × confidence ×
  joint_response, **not the raw per-draw output** (confirmed working; at N=40 the raw output
  would be ~2.5M rows per fit, which would defeat the entire point of slimming this format down).
  Observed counts for the same cells live in the already-saved `agg`, so the Day-5 PPC script
  (`code/04_ppc_and_comparison/ppc_joint_counts.R`, not yet implemented) joins the two rather than
  this summary duplicating the observed side.

The 16 result files already produced by the stopped launch (old, full-`brmsfit` format) were
deleted so every cell reruns cleanly in the new format — none were lost science, since the run
had barely started (16 of 2160 planned rows, all G0).

### Run order: G1 → G0 → G2

`code/00_setup/02_create_grid.R`'s cell-ordering `arrange()` now uses
`factor(generator, levels = c("g1", "g0", "g2"))` instead of alphabetical order, so
`run_grid.R` (which processes pending rows in `config/grid.csv`'s file order) runs all G1 cells
first, then G0, then G2. User-directed; no scientific effect (grid cells are independent), just a
priority ordering (G1 is the primary-question generator).

### `.gitattributes`

Added `* text=auto eol=lf` to stop line-ending churn (Windows CRLF vs. the repo's LF convention)
showing up as spurious diffs on `renv.lock` and other text files across sessions/machines.

## 2026-09-28 — v2 extension 1: posterior predictive checks on all 480 G2 fits

Written and committed before any v2 PPC statistic was computed. v2 work lives on the
`v2-extensions` branch. Outputs go to `data/processed/v2/` and `outputs/figures/v2/`; no v1 file is
overwritten.

**Purpose.** The report's model-adequacy claim is that aggregate PPCs do not reveal the Gaussian
misspecification that LOO detects. In v1 this rests on one replicate per model (grid 1321/1322,
N = 40, T = 200, d′ = 1.5, rep 1). This extension evaluates the claim across all 240 G2 datasets,
each fitted under both families.

**What was already seen.** Before writing this section the author had seen the v1 results: the single
replicate (misspecified RMSE largest, its four largest cell errors at the highest confidence level) and
the ELPD summaries (correct family preferred in 96.2% of pairs, 72.9% by > 2 SE). The predictions below
are made with that knowledge; no v2 statistic had been computed.

**Data (no refitting).** Every G2 result file stores `epred_summary` (per participant × stimulus ×
response × confidence posterior mean, median and 95% interval of the predicted cell probability,
conditional on stimulus) and the observed counts in `agg`. Checked on 2026-09-28: all 480 files have
a non-empty `epred_summary`; predicted probabilities sum to 1 within participant × stimulus;
478/480 fits are `pass`. Posterior draws of the predictions were not saved, so replicated-data
p-values cannot be computed. The statistics below use the posterior-mean prediction.

**Statistics (per fit).** Let n be the observed count and p̂ the posterior-mean predicted probability
of a cell, with n_s the participant's trial count for that stimulus.

1. **Aggregate RMSE (primary, same as v1).** Pool observed and predicted counts over participants
   into the 16 stimulus × response × confidence cells, convert to proportions within stimulus, and
   take the RMSE of observed − predicted. This is the v1 definition in `ppc_joint_counts.R`.
2. **Highest-confidence discrepancy (secondary, v1-motivated).** Mean absolute observed − predicted
   proportion over the four confidence = 4 cells of statistic 1. It was chosen because of the pattern
   seen in the single v1 replicate, so it is secondary: it does not enter Kept or Reversed, but it
   does trigger Qualified (see the decision rule).
3. **Participant-level Pearson X².** Σ over participant × cell of (n − n_s p̂)² / (n_s p̂), divided by
   the number of participant × stimulus cells minus the number of participant × stimulus
   constraints (N × 16 − N × 2). This is scaled by sampling noise and so is comparable across N and T,
   unlike statistics 1–2. It ignores posterior uncertainty in p̂ (a small anticonservative effect,
   shared by both families). **Small expected counts:** at T = 100 there are about 50 trials per
   stimulus over 8 cells, so many expected counts are below 5. No cells are pooled. The statistic is
   used only as a discrepancy measure calibrated against the correct-family fits of the same cell and
   is never referred to a χ² distribution, so an unreliable χ² approximation does not bias the
   comparison. For every fit the proportion of participant × cell entries with n_s p̂ < 5 (and < 1) is
   reported beside the statistic.

**Comparisons.**

- **Paired (240 datasets):** misspecified − correct difference in each statistic, and the ratio
  misspecified / correct; the proportion of pairs in which the misspecified fit is worse; median and
  90% range of the difference and of the ratio, by cell.
- **Calibrated detection (the analyst's view, who sees one model only):** for each of the 12
  N × T × d′ cells, the threshold is the 19th order statistic of the 20 correct-family values in that
  cell (equivalently `quantile(x, 0.95, type = 1)`). A misspecified fit is detected if its statistic
  is strictly greater than the threshold, so the false-alarm rate among correct fits is exactly
  1/20. Detection rate = proportion of the cell's misspecified fits detected, with a Wilson 95%
  interval, set beside LOO's > 2 SE preference rate for the same cell.
- **Pooled detection** = the mean of the 12 per-cell detection rates, each using its own
  cell-specific threshold. For statistic 3 only, a secondary view uses one threshold pooled over all
  240 correct fits (`quantile(x, 0.95, type = 7)`); it does not enter the decision rule.
- **Oracle threshold.** The threshold comes from the correct model's own reference distribution,
  which a real analyst would not know. Detection rates are therefore an optimistic upper bound on
  what PPC would achieve in practice: a low rate here means practical detection is lower still.
- **Trend:** detection rate and paired difference against N, T and d′ (descriptive; no p-values on
  replicates, as in v1).

**Predictions.**

- P1. In most pairs (> 50%) the misspecified fit has the larger aggregate RMSE, and the median ratio
  misspecified / correct aggregate RMSE is < 1.5. (An earlier draft stated an absolute bound,
  median difference < 0.005; since v1 RMSEs are only 0.0024–0.0072 that bound was almost certain to
  hold and tested little, so it was replaced by the ratio before any statistic was computed.)
- P2. The highest-confidence discrepancy shows the difference more clearly than the aggregate RMSE
  (higher paired proportion).
- P3. The calibrated detection rate for the aggregate RMSE is well below LOO's > 2 SE rate in most
  cells and rises with T and N.

**Decision rule for the report's claim (fixed now).** Categories are evaluated in order: Reversed,
then Qualified, then Kept; the first that applies is the verdict. Otherwise the result is Mixed.

1. **Reversed:** pooled detection ≥ 80% for statistic 1. The v1 claim is withdrawn and the limitations
   section says the v1 single replicate was unrepresentative.
2. **Qualified:** any single cell has detection ≥ 80% for statistic 1, 2 or 3. The claim is
   restricted to the cells where detection is low, and the report names the statistic and conditions
   under which PPC does detect it. Statistic 2 is secondary and v1-motivated: it does not enter Kept
   or Reversed, but it does trigger Qualified. If it reaches ≥ 80% detection in any cell, the report
   must name it and restrict the "aggregate PPC does not reveal" claim accordingly.
3. **Kept:** pooled detection < 50% for both statistic 1 and statistic 3, and statistic 1's
   detection is below LOO's > 2 SE rate in at least 10 of 12 cells. The report keeps "aggregate PPC
   does not reveal the misspecification", now supported by 240 pairs.
4. **Mixed:** none of the above. Reported cell by cell, without choosing the favourable statistic.

**Inclusion.** Pre-specified failed-fit rule applies: primary analysis uses `pass` and `fail` fits
(flagged); a pass-only sensitivity analysis is reported. A pair enters the paired analysis only if
both fits have `epred_summary`.

**Check before use.** The script recomputes statistic 1 for grid 1321/1322 from `epred_summary` and
must match `data/processed/ppc_discrepancy_summary.csv` to 1e-6; otherwise it stops.

**Stopping rule.** One pass over the 480 existing files. No refitting, no added statistics after the
results are seen. Any extra analysis is logged as exploratory in `docs/analysis_log.md`.

**Planned outputs.** `code/04_ppc_and_comparison/g2_ppc_all.R`;
`data/processed/v2/g2_ppc_by_fit.csv`, `g2_ppc_paired.csv`, `g2_ppc_detection_by_cell.csv`;
`outputs/figures/v2/fig_g2_ppc_all.png`.

**Revision log (all before any v2 statistic was computed).** First version committed in `3cc7e71`.
Revised after a design review, same day: decision categories ordered and made exclusive (Mixed as
the remainder); pooled detection defined as the mean of per-cell rates, with a pooled threshold for
statistic 3 as a secondary view only; threshold fixed as the 19th order statistic with strict
exceedance; the oracle nature of the threshold stated; P1 changed from an absolute to a ratio bound;
handling of small expected counts in statistic 3 stated; statistic 2 marked secondary and
v1-motivated, excluded from Kept and Reversed but able to trigger Qualified.

**Deviation (2026-09-28, after the analysis).** The Reversed rule required the limitations to say that
the v1 single replicate was unrepresentative. The data do not support that: its misspecified/correct
RMSE ratio (1.9) lies within the range observed across the 240 pairs. The report instead states that
the replicate was not unusual and that its interpretation ("small, so not flagged") was wrong. The
verdict itself (Reversed) is unchanged.

## 2026-09-29 — v2 extension 2: replicated-data posterior predictive p-values (48 stored fits)

Written and committed before any extension-2 statistic was computed. Outputs go to
`data/processed/v2/` and `outputs/figures/v2/`; no earlier file is overwritten.

**Purpose.** Extension 1 showed that the Gaussian fit's aggregate discrepancy is systematically larger
than the correct fit's, but detection was calibrated against the correct family's own distribution
(an oracle). The report (v1.1, §5) states that practical references were not tested. This extension
asks whether a reference an analyst actually has, the fitted model's own replicated data, flags the
misspecification.

**What was already seen.** The v1.1 results, including the oracle detection rates and paired
ratios for every G2 dataset (so also for the 24 datasets used here), were known when this section
was written. The predictions below are made with that knowledge.

**Data (no refitting).** The 48 G2 fits whose full `brmsfit` was kept (`rep_id` 1–2 in each of the
12 N × T × d′ cells, correct and Gaussian families: 24 paired datasets). `simulate_g2_gumbel.R`
must be sourced first so `gumbel_min_lcdf`/`lccdf` are in scope for the Gumbel-family predictions.

**Precondition (checked before any statistic; the script stops if it fails).** For every one of
the 48 files: the `fit` element is a non-null `brmsfit`; `hmetad::epred_draws_metad(fit, agg)`
runs; per-draw cell probabilities sum to 1 within participant × stimulus × draw (to 1e-8); and
their mean over draws reproduces the stored `epred_summary$epred_mean` to 1e-8.

**Replicated data.** For each posterior draw s (all 4,000) and each participant × stimulus, draw
y_rep ~ Multinomial(n_ps, p_ps^(s)), where n_ps is that participant's observed trial count for the
stimulus (fixed by the design) and p_ps^(s) the draw's predicted cell probabilities. This matches
the aggregated multinomial likelihood used in fitting. RNG seed per fit: `seed_base + grid_id`.

**Statistics.** The three extension-1 statistics, computed as realised discrepancies
T(y, θ^(s)) and T(y_rep^(s), θ^(s)) against the draw's own probabilities (not the posterior mean):
(1) aggregate RMSE, primary; (2) highest-confidence discrepancy, secondary; (3) participant-level
Pearson X²/df, secondary. Posterior predictive p-value: p = proportion of draws with
T(y_rep, θ) ≥ T(y, θ). A fit is **flagged** if p < 0.05 (one-sided: large discrepancy only).

**Summaries.**

- Flag rate among Gaussian fits (practical detection) and among correct fits (false alarm), each
  out of 24, with Wilson 95% intervals; per-cell counts (0–2) listed but not interpreted.
- Descriptive split by T (100 / 200 / 400; 8 datasets each) and by N (20 / 40; 12 each).
- On the same 24 datasets: oracle detection from extension 1 and LOO's > 2 SE preference.
- Distribution of p-values for each family (known to be conservative: under a correct model they
  concentrate near 0.5 rather than being uniform).

**Predictions.**

- P1. Correct-family fits are rarely flagged (≤ 2 of 24 for each statistic).
- P2. Practical detection by statistic 1 is lower than oracle detection on the same 24 datasets.
- P3. Where it occurs, practical detection is concentrated at T = 400.

**Decision rule for the report's statement on practical PPC (fixed now; evaluated in this order,
first match wins).**

1. **Not interpretable:** more than 2 of 24 correct fits flagged by statistic 1. The report says
   the replicated-data check had an excess false-alarm rate and draws no conclusion from it.
2. **Practical PPC detects:** statistic 1 flags ≥ 18 of 24 Gaussian fits. The report states that
   a replicated-data PPC on the aggregate discrepancy flagged the misspecification in most datasets.
3. **Practical PPC misses:** statistic 1 flags ≤ 6 of 24 Gaussian fits. The report states that the
   signal is visible when fitted families are compared (LOO, or discrepancies side by side) but a
   single model's replicated-data PPC on the aggregate discrepancy usually did not flag it.
4. **Partial:** otherwise; reported by T and N without choosing a favourable statistic.

Statistics 2 and 3 do not change the category. If statistic 2 flags ≥ 18 of 24 Gaussian fits with
≤ 2 of 24 false alarms, the report additionally names it as a targeted check that did flag the
misspecification.

**Limitations fixed in advance.** 24 pairs, 2 per cell: per-cell results are not interpretable and
the rates carry wide intervals. The datasets are replications 1–2 only, chosen by the storage rule,
not by outcome. Posterior predictive p-values are conservative, so low detection partly reflects
the method, not only the size of the misfit.

**Inclusion.** All 48 fits (2 G2-correct fits failed diagnostics; any among these 48 are flagged
and a pass-only sensitivity is reported).

**Stopping rule.** One pass. No added statistics or thresholds after results are seen; anything
further is logged as exploratory.

**Planned outputs.** `code/04_ppc_and_comparison/g2_ppp_fullfits.R`;
`data/processed/v2/g2_ppp_by_fit.csv`, `g2_ppp_summary.csv`; `outputs/figures/v2/fig_g2_ppp.png`.

## What this project must not claim

In particular: do not claim `log_M` "recovers" σ_c numerically; do not
report 95% CI coverage for σ_c using `log_M` intervals; do not call the G1 DDM process
"non-Gaussian" without separately establishing the empirical distributional feature tested; do
not treat a successful MCMC fit as evidence of generative correctness without PPCs; do not make
trial-level LOO claims when the likelihood is fit to aggregated subject-level cell counts.
