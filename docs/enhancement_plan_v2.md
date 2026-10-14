> SUPERSEDED by docs/v3_plan.md and docs/v3b_plan.md; kept for the record.

# Project 1 — Enhancement plan towards a submittable paper (v2.0)

**Repository:** `metacognitive-noise-recovery` (currently `v1.2.1`, branch `main`)
**Plan written:** 2026-09-29
**Target:** a PsyArXiv preprint plus submission to a methods-oriented journal
**Estimated effort:** about 20–25 *working days*. Convert this to calendar weeks using your real weekly hours.

---

## 0. How to use this document

- Work through the stages **in order**. Each stage ends with a **decision gate**. If a gate fails, stop and follow the action given for that case. Do not push on.
- Every stage lists: *why*, *what to do* (numbered steps), *code sketch*, *output files*, *checks for understanding*, and *pitfalls*.
- Code sketches are **illustrative**. They are written against the repo's existing conventions (`fit_one_hmetad()`, `compiled_results.csv`, `.qs2` interim files, `config/design.yml`). Where a line depends on an `hmetad`/`brms` behaviour that has not yet been verified in this repo, it is marked **`# VERIFY`**. Test these on one small case before running anything at scale.
- Keep recording in the files you already use:
  - `docs/design_decisions.md`: every new locked decision, dated.
  - `docs/analysis_log.md`: what was run, in order, including bugs.
  - Commit each *pre-specified plan* **before** running the analysis it governs, and quote the commit hash in the log (as you did with `32de75f`).

### 0.1 Set-up (30 minutes)

```bash
git checkout -b v2-enhancement
mkdir -p code/06_empirical data/raw/confidence_db data/processed/v3 outputs/figures/v3 docs/v3
```

Add to `.gitignore` (raw data are already ignored by `data/raw/*`; this is a safety check):

```
data/raw/confidence_db/*
```

Add a `v3:` block to `config/design.yml` for all new constants (seeds, fold counts, inclusion thresholds). As before, **no script hardcodes these values**.

```yaml
v3:
  seed_offset: 3000000          # added to seed_base for every v3 simulation/fit
  kfold:
    k: 5
    subset: "rep_id <= 2"       # the 24 G2 dataset pairs with stored full fits
  mixture_check:
    n_participants: 40
    n_trials: 400
    dprime_low: 0.5
    dprime_high: 2.0
    replications: 20
  empirical:
    min_trials_per_participant: 100
    min_participants: 15
    min_level_share: 0.05       # confidence-level merging rule (Stage 3.4)
    k_min: 3
    k_max: 6
    elpd_small: 4               # |ΔELPD| below this = inconclusive
```

---

## 1. The paper in one paragraph (keep this visible)

> **Question.** When the Gaussian signal-distribution assumption in hierarchical meta-d′ (`hmetad`) is wrong, are (i) the estimate of metacognitive efficiency, (ii) its uncertainty, and (iii) the standard diagnostic workflow still trustworthy? And (iv) does the problem arise in real confidence data?
>
> **Contribution relative to prior work.** Rausch, Hellmann & Zehetleitner (2023) show that meta-d′/d′ can be confounded with discrimination performance and criteria across alternative *confidence mechanisms*, all with Gaussian sensory evidence. This study isolates a *signal-distribution* violation. It quantifies its inferential consequences in a hierarchical Bayesian implementation, tests whether the analyst can detect it, and measures its prevalence in open data.

**Paper architecture:**
sensitivity check (G1) → consequence of misspecification (G2) → detectability (LOO / K-fold / targeted PPC) → empirical relevance (Confidence Database).

**Claims to avoid in every draft:**
- "meta-d′ is invalid"
- "first to show meta-d′ depends on assumptions"
- "log M measures σ_c"
- "Gumbel-min is the true distribution of human evidence"

---

## Stage 0 — Literature positioning (essential; 0.5–1 day)

**Why.** Confirm that the gap still exists before investing in new analyses.

**Minimum concepts.** Construct validity (Rausch et al.) versus inferential validity (your study). What a *pseudo-true parameter* is: the value a misspecified model converges to as the data grow.

**Steps.**
1. Read Rausch, Hellmann & Zehetleitner (2023, *Psychological Methods*), especially the Methods and Discussion. Record:
   - (a) the six generative models;
   - (b) how meta-d′ was estimated (MLE? hierarchical?);
   - (c) whether any model changes the **signal distribution** rather than the confidence mechanism;
   - (d) whether they assess interval coverage or diagnostics.
2. Read the `hmetad` paper/tutorial (O'Neill & Fleming) and the `alternative_distributions` vignette. Record whether *any* Gaussian-versus-non-Gaussian misspecification simulation exists.
3. Find the recognition-memory reference the vignette cites for Gumbel-min. Record in one sentence why Gumbel-min was proposed there.
4. Write `docs/v3/positioning.md` with three short sections:
   - *What they did*;
   - *What this study adds*;
   - *What this study does not claim*.

**Output.** `docs/v3/positioning.md` (≤ 1 page).

**Check for understanding.**
- Why is a d′-dependent bias under misspecification an *instance* of the Rausch et al. concern rather than a new discovery?
- What does your study test that theirs does not?

**Decision gate 0.**
- ✅ Proceed if no existing work runs a Gaussian-versus-Gumbel-min (or similar signal-distribution) misspecification study of hierarchical meta-d′.
- ❌ If one exists: stop. Compare its design with yours and decide whether your contribution becomes "replication plus empirical extension" (still preprint-worthy) before continuing.
- Note: the *practical relevance* of Gumbel-min is **not** a Stage 0 criterion. Stage 3 tests it.

---

## Stage 1 — Re-analysis of existing simulations (essential; 1–2 days; no new fits)

**Why.** The highest-return stage. It separates misspecification bias from baseline estimation error and becomes the paper's main simulation result.

**Definitions** (both computed per G2 dataset, paired by `cell_id`/`rep_id`):

- Misspecification effect: Δ_mis = log M̂(Gaussian) − log M̂(Gumbel-min correct)
- Baseline bias: Δ_base = log M̂(correct) − log M_true (with log M_true = −1)

### Steps

1. Create `code/03_recovery_analysis/relative_bias.R`. Read `data/processed/compiled_results.csv`, filter `generator == "g2"`, and pivot so that each row is one dataset holding both variants.
2. For each N × T × d′ cell, compute:
   - mean and median Δ_mis, the 2.5–97.5% range across replicates, and MCSE (= SD/√n);
   - mean Δ_base;
   - coverage of the true value for each variant (`log_M_q025 <= -1 & log_M_q975 >= -1`), with MCSE;
   - mean 95% CrI width for each variant;
   - number of `pass` fits.
3. Test d′ dependence **within** matched N × T × rep: Δ_mis(d′ = 0.75) − Δ_mis(d′ = 1.5). The earlier quick check gave +0.097 (SE 0.011).
4. **Persistence check.** Plot Δ_mis against T, faceted by N and d′, with the CrI width on a second panel. The expected message is "Δ_mis does not shrink while intervals narrow: the wrong model becomes more confidently wrong."
5. **G0 bias (bounded, not explained).** Compare Δ_base (G2-correct) with G0 bias cell by cell (a scatter with an identity line). Report bias against N and T. Anything else goes under Limitations.
6. Write `data/processed/v3/g2_relative_bias.csv`, `data/processed/v3/g2_dprime_contrast.csv` and `outputs/figures/v3/fig_relative_bias.png`.

### Code sketch

```r
suppressPackageStartupMessages(library(dplyr)); library(tidyr)
cr <- readr::read_csv(here::here("data/processed/compiled_results.csv"), show_col_types = FALSE)
truth <- yaml::read_yaml(here::here("config/design.yml"))$truth$log_M

g2 <- cr |>
  filter(generator == "g2") |>
  mutate(covers = log_M_q025 <= truth & log_M_q975 >= truth,
         width  = log_M_q975 - log_M_q025) |>
  select(n_participants, n_trials, dprime_target, rep_id, fit_variant,
         status, log_M_mean, covers, width) |>
  pivot_wider(names_from = fit_variant,
              values_from = c(status, log_M_mean, covers, width))

g2 <- g2 |> mutate(
  d_mis  = log_M_mean_misspecified - log_M_mean_correct,
  d_base = log_M_mean_correct - truth
)

mcse <- function(x) sd(x) / sqrt(length(x))
cell <- g2 |>
  group_by(n_participants, n_trials, dprime_target) |>
  summarise(
    n = n(),
    d_mis_mean = mean(d_mis), d_mis_mcse = mcse(d_mis), d_mis_median = median(d_mis),
    d_mis_lo = quantile(d_mis, .025), d_mis_hi = quantile(d_mis, .975),
    d_base_mean = mean(d_base), d_base_mcse = mcse(d_base),
    cov_correct = mean(covers_correct), cov_gauss = mean(covers_misspecified),
    width_correct = mean(width_correct), width_gauss = mean(width_misspecified),
    n_pass_both = sum(status_correct == "pass" & status_misspecified == "pass"),
    .groups = "drop")

contrast <- g2 |>
  select(n_participants, n_trials, rep_id, dprime_target, d_mis) |>
  pivot_wider(names_from = dprime_target, values_from = d_mis, names_prefix = "d") |>
  mutate(diff = d0.75 - d1.5)
# Report mean(diff) and mcse(diff) overall and by N x T.
```

> Note: `rep_id` is *not* a shared seed across d′ levels. The d′ contrast is therefore an independent-sample comparison, even though it is matched by index. State this in the Methods and compute the SE as for independent groups if you prefer to be conservative.

**Primary sensitivity.** Repeat the table with `status == "pass"` fits only (your pre-specified pass-only rule).

**Check for understanding.**
- Why is coverage loss largely a *consequence* of Δ_mis rather than a separate finding?
- If Δ_mis stayed constant as T → ∞, what would that say about the pseudo-true value?

**Pitfalls.**
- Reporting "bias +0.06 to +0.20" (relative to truth) as the misspecification effect. The primary quantity is Δ_mis.
- Calling the d′ dependence novel. Cite Rausch et al. as the conceptual predecessor.

**Decision gate 1.**
- ✅ Proceed if Δ_mis is consistently positive across cells and the baseline/misspecification decomposition is clear.
- ⚠️ If Δ_mis changes sign across cells, the story becomes "direction depends on design". Rewrite the claims before continuing.

---

## Stage 2 — Robust model comparison (essential; 2–3 days incl. ~3–6 h of computing)

**Why.** 181/240 correct-model fits have at least one Pareto k > 0.7, so the 96.2% LOO selection rate cannot be the headline without a check that does not rely on the PSIS approximation.

**Facts from the repo that shape this stage:**
- The LOO unit is **one participant's aggregated count vector** (`loo_comparison.R` header).
- No fit was run with `save_pars(all = TRUE)`, so **moment matching is not available without refitting**. Use exact K-fold instead.
- Full `brmsfit` objects exist only for `rep_id <= 2`: 24 dataset pairs = 48 fits.

### 2.1 Report LOO reliability properly (0.5 day, no refits)

Extend `loo_comparison.R` (or add `loo_reliability.R`) to report:
- per variant: the share of participant-observations with k > 0.7 and with k > 1, and the number of fits with any k > 0.7;
- the full distribution of ΔELPD = elpd(correct) − elpd(Gaussian) by cell (a violin or strip plot), not only the proportion that favour the correct model;
- ΔELPD sign agreement when fits with **any** k > 1 are excluded.

### 2.2 Exact participant-grouped K-fold (1–2 days)

**Question it answers:** does the correct family predict *held-out participants* better, without PSIS?

**Pre-specify first** (commit to `docs/design_decisions.md` before running):
- K = 5 folds, grouped by participant, with fold assignment seeded from `seed_base + v3.seed_offset + grid_id`.
- New-participant prediction integrates over the population distribution (new random-effect levels).
- Primary outcome: sign of Δelpd_kfold and agreement with the LOO sign on the same 24 pairs.
- A disagreement is **reported, not a reason to stop**: K-fold becomes the primary model-comparison metric.

**Step 1: test on one fit first.**

```r
r <- qs2::qs_read(here::here("data/interim/g2_cell-0961_rep-01_correct_grid-00961.qs2"))
source(here::here("code/01_simulate/simulate_g2_gumbel.R"))   # gumbel_min_* must exist for refits/predictions

# VERIFY 1: log_lik on new participants works for hmetad's custom family
ll_new <- brms::log_lik(r$fit, newdata = r$agg[1:2, ], allow_new_levels = TRUE,
                        sample_new_levels = "uncertainty")
dim(ll_new)   # expect draws x 2

# VERIFY 2: brms::kfold refits a hmetad/stanvars model correctly
kf <- brms::kfold(r$fit, K = 5, folds = "grouped", group = "participant",
                  save_fits = FALSE, seed = 1,
                  allow_new_levels = TRUE, sample_new_levels = "uncertainty")  # VERIFY argument passing
kf$estimates
```

If `kfold()` fails on the custom family (for example because the Gumbel stanvars are not carried into the refit), write the loop by hand:

```r
kfold_manual <- function(r, K, seed, distribution, extra_stanvars = NULL) {
  set.seed(seed)
  ids   <- unique(r$agg$participant)
  folds <- sample(rep_len(1:K, length(ids)))
  elpd_i <- numeric(0)
  for (k in 1:K) {
    test_ids <- ids[folds == k]
    # Refit on the training participants using the raw trial data. The repo's
    # compact record stores agg only, so re-simulate the raw data from the
    # stored seed and generator (deterministic). VERIFY that the regeneration
    # reproduces r$agg exactly before trusting it.
    fit_k <- fit_one_hmetad(train_raw, K = 4, distribution = distribution,
                            extra_stanvars = extra_stanvars, seed = seed + k)$fit
    ll <- brms::log_lik(fit_k, newdata = r$agg[r$agg$participant %in% test_ids, ],
                        allow_new_levels = TRUE, sample_new_levels = "uncertainty")
    elpd_i <- c(elpd_i, matrixStats::colLogSumExps(ll) - log(nrow(ll)))
  }
  c(elpd = sum(elpd_i), se = sqrt(length(elpd_i)) * sd(elpd_i))
}
```

**Step 2: time it.** One refit is about 2–4 min, so 48 fits × 5 folds = 240 refits. At 5 concurrent fits that is roughly 2–4 h on your machine. Run through a new `code/04_ppc_and_comparison/run_kfold.R` that follows the resumable pattern of `run_one_cell.R` (skip the pair if its output file exists).

**Step 3: outputs.** `data/processed/v3/g2_kfold.csv` (one row per pair: elpd and SE per family, Δ, sign agreement with LOO) and a short results paragraph.

**Check for understanding.**
- Why is the LOO unit a participant here, and why does that make high Pareto k values likely in a hierarchical model?
- What does grouped K-fold test that trial-level CV would not?

**Pitfalls.**
- Predicting held-out participants with their *own* fitted random effects (leakage). New levels must be sampled.
- Passing trial-level data where aggregated data are expected, or vice versa. Always check `nrow()` and the `N` column layout.

**Decision gate 2.**
- ✅ K-fold agrees with LOO in most pairs: report LOO as supported by K-fold.
- ⚠️ Substantial disagreement: make K-fold primary and down-weight the 96.2% figure. Continue either way.

---

## Stage 2b — Difficulty-mixture control simulation (essential before Stage 3; 0.5–1 day incl. ~1 h computing)

**Why.** Many Confidence Database datasets mix several difficulty levels (or use staircases). A mixture of Gaussian evidence distributions with different d′ is itself non-Gaussian. It could make Gumbel-min win for reasons unrelated to the true signal shape. You must know how large this artefact is **before** interpreting real data.

**Design** (pre-specify in `design_decisions.md`):
- **G3-mix:** Gaussian generator, per participant half the trials at d′ = 0.5 and half at d′ = 2.0 (pooled), N = 40, T = 400, log M = −1, 20 replications. Fit (a) Gaussian and (b) Gumbel-min, **ignoring** difficulty.
- **G3-control:** the same but a single d′ = 1.25. Fit both families. This gives the false-alarm rate of "Gumbel-min preferred" when the data are truly Gaussian.
- **Optional G3-modelled:** refit G3-mix with difficulty as a predictor of d′. This shows that modelling difficulty removes the artefact.

**Code sketch** (reuses the G2 generator pattern with the default normal CDF):

```r
sim_mix <- function(n_participants, n_trials, d_lo, d_hi, log_M, seed) {
  half <- n_trials / 2
  lo <- withr::with_seed(seed,     hmetad::sim_metad_participant(
          N_participants = n_participants, N_trials = half,
          mean_dprime = d_lo, sd_dprime = 0, mean_c = 0, sd_c = 0,
          mean_M = log_M, sd_M = 0,  # other z_c2 arguments exactly as in simulate_g2_gumbel()
          summarize = FALSE))        # default lcdf/lccdf = normal
  hi <- withr::with_seed(seed + 1, hmetad::sim_metad_participant(
          N_participants = n_participants, N_trials = half,
          mean_dprime = d_hi, sd_dprime = 0, mean_c = 0, sd_c = 0,
          mean_M = log_M, sd_M = 0, summarize = FALSE))
  dplyr::bind_rows(dplyr::mutate(lo, difficulty = "hard"),
                   dplyr::mutate(hi, difficulty = "easy"))
  # VERIFY: participant IDs align across the two calls (same 1..N labels)
}
```

About 80–120 fits in total (under 2 h at your throughput).

**Outputs.** `data/processed/v3/g3_mixture.csv` with the share of datasets where LOO (and, if cheap, K-fold) prefers Gumbel-min in G3-mix versus G3-control, plus Δlog M between families.

**Decision gate 2b.**
- If G3-mix makes Gumbel-min win often, Stage 3 **must** model difficulty (or restrict to single-difficulty datasets). Otherwise any empirical "Gumbel preference" is uninterpretable.
- If it does not, keep the difficulty rules in Stage 3 anyway: they are cheap insurance.

---

## Stage 3 — Empirical relevance: the Confidence Database (main extension; 6–9 days)

**Why.** It answers the reviewer question "does this matter for real data?"

**Resource.** Rahnev et al. (2020), *The Confidence Database*, *Nature Human Behaviour*, 4, 317–325. The data are on OSF (the link is in the paper). Datasets come as `data_<Name>.csv` with a matching readme, plus a summary spreadsheet. **VERIFY** the current file layout, column names (typically `Subj_idx`, `Stimulus`, `Response`, `Confidence`, …) and the database's citation requirements when you download. Cite the database *and* each original study you use.

### 3.1 Lock the empirical plan first (1 day, before looking at any fit)

Write `docs/v3/empirical_plan.md`, commit it, and record the hash in `analysis_log.md`. Optionally register it on OSF. It must fix everything in 3.2–3.6.

### 3.2 Inclusion criteria (pre-specified)

A dataset (or a condition within it) is included if **all** of the following hold:
1. The type-1 task is binary (two stimulus classes, two responses), so stimulus and response map to 0/1.
2. Confidence is given on **every** trial on an ordinal scale with ≥ 3 levels, or on a continuous scale (handled in 3.4).
3. Confidence is a separate report, not a single combined choice-plus-confidence scale. If it is combined, it can only be included if choice and confidence can be split unambiguously.
4. ≥ `min_participants` participants with ≥ `min_trials_per_participant` trials per analysed unit after exclusions.
5. **Difficulty.** Either a single difficulty level, or difficulty coded in a column so that it can be modelled (3.5). Datasets with adaptive staircases are included but **flagged** (`staircase = TRUE`) and analysed as a pre-specified subgroup.
6. The domain is recorded (perception / memory / other). **Primary analysis: perception.** Memory is a pre-specified secondary subgroup, which matters because Gumbel-min was motivated by recognition memory.

Trial exclusions: missing response or confidence, and RTs flagged invalid by the original authors, if a column exists. Apply **nothing else**.

**Stopping rule for dataset count.** Screen all datasets, then analyse the eligible ones in alphabetical order until the computing budget (set after the pilot, 3.7) is used up. **Do not choose datasets by their results.**

### 3.3 Screening script (1 day)

`code/06_empirical/01_screen_datasets.R` produces `data/processed/v3/empirical_inventory.csv` with one row per dataset and columns:
`dataset, domain, n_participants, median_trials, binary_task, conf_levels, conf_continuous, has_difficulty, staircase, n_conditions, eligible, reason_excluded`.

Every exclusion needs a reason string. This table becomes a supplementary table.

### 3.4 Confidence-scale rule (pre-specified, applied per dataset)

1. If the scale is continuous or has more than `k_max` levels: bin into K = 4 by **within-participant quartiles** (the same rule as G1).
2. If it is ordinal with ≤ `k_max` levels: start from the native K. While any level holds < `min_level_share` of the pooled trials and K > `k_min`, merge that level with its **adjacent** level of smaller share. Record the final K.
3. Recode to 1..K with **high = K**.

Unit-test this with `testthat` (for example: `c(1,1,2,3,3,3,4)` should merge as expected; continuous input returns four levels per participant).

### 3.5 Model specification (pre-specified)

For each analysed unit, fit both `distribution = "normal"` and `distribution = "gumbel_min"` with the **same** formula and priors as the simulations.

| Dataset structure | Formula (sketch) |
|---|---|
| Single condition, single difficulty | as the simulations: `N ~ 1 + (1|participant)`, `dprime + c ~ 1 + (1|participant)` |
| Several difficulty levels | `dprime + c ~ difficulty + (1|participant)`; log M held constant (`N ~ 1 + (1|participant)`) **primary**; `N ~ difficulty + …` sensitivity |
| Several experimental conditions | `N ~ condition + (1|participant)`, `dprime + c ~ condition + (1|participant)` so that the condition contrast in log M can be extracted |

`fit_one_hmetad()` currently builds intercept-only formulas and aggregates by `participant` only. Add an optional `predictors` argument:
- aggregate with `hmetad::aggregate_metad(data, participant, <predictor>, K = K)`  **# VERIFY that extra grouping columns are accepted**;
- append the predictor to the relevant right-hand sides in `.build_metad_formula()`;
- add a prior for new slope coefficients, for example `normal(0, 1)` on `class = "b"` for log M. Lock it and verify the prior class names with `brms::get_prior()` first (see the prior-class gotcha in the wrapper header).

Write a `testthat` test that the extended wrapper with no predictors reproduces the old formula exactly.

### 3.6 Outcomes and classification (pre-specified)

Per analysed unit:
1. **ΔELPD** = elpd(Gumbel-min) − elpd(Gaussian), from LOO. Use participant-grouped K-fold (Stage 2 code) whenever > 10% of participants have k > 0.7.
2. **Δlog M** = population log M̂(Gaussian) − log M̂(Gumbel-min), with a 95% interval from paired draws **only if** the parameterisations are comparable within `hmetad`. Otherwise report it descriptively and say so.
3. **Condition contrast change** (multi-condition datasets): [log M̂₁ − log M̂₂] under Gaussian versus under Gumbel-min. Report whether the sign or the 95%-interval conclusion changes.
4. **Highest-confidence PPC discrepancy** for each family, using your v1.2 `stat2_highconf` with replicated data. Save the predictive draws this time.

Classification of each unit (mutually exclusive; applied in this order):

| Category | Rule |
|---|---|
| Diagnostically unreliable | Either fit fails the convergence rules after escalation, **or** K-fold was required but could not be run |
| Clear Gumbel-min | ΔELPD > `elpd_small` **and** ΔELPD > 2 SE |
| Clear Gaussian | ΔELPD < −`elpd_small` **and** \|ΔELPD\| > 2 SE |
| Inconclusive | otherwise |

The primary summary is the count and proportion in each category, split by domain and staircase flag, plus the distribution of Δlog M. **No** meta-analytic pooling of ΔELPD: its scale depends on data size.

### 3.7 Pilot (1 day)

Run 3.3–3.6 end to end on **two** eligible perception datasets (the first two alphabetically). Check:
- diagnostics pass;
- each fit's time (this sets the computing budget and hence the number of datasets);
- the confidence-cell counts are not dominated by empty cells;
- the Gumbel stanvars and the predictors work together.

**Decision gate 3 (after the pilot).** Scale up only if the pipeline runs cleanly on both datasets and the per-fit time allows ≥ 8 datasets within your budget. If not, fix the issue or reduce the scope (perception-only, single-difficulty-only) **by amending the plan with a dated note before running more**.

### 3.8 Main run (3–5 days, mostly unattended)

`code/06_empirical/03_run_empirical.R`: resumable, one `.qs2` per unit × family in `data/interim/empirical/`. Keep full fits (the datasets are few). Save LOO, predictive draws for the PPC, and the diagnostics.

`code/06_empirical/04_summarise_empirical.R` writes:
- `data/processed/v3/empirical_results.csv` (one row per unit);
- `data/processed/v3/empirical_categories.csv`;
- `outputs/figures/v3/fig_empirical.png`: panel A, the category counts by domain; panel B, Δlog M per unit with intervals, ordered by ΔELPD.

**Check for understanding.**
- Why could a mixture of difficulties make Gumbel-min win even when each difficulty level is Gaussian?
- Why is the condition-contrast change more important for applied researchers than the absolute shift in log M?
- Why is ΔELPD not meta-analysed across datasets?

**Pitfalls.**
- Choosing datasets after seeing the results (forking paths). The inventory and the alphabetical rule prevent this.
- Mis-coding stimulus/response (1/2 → 0/1) or confidence direction (check each readme).
- Treating "inconclusive" as "Gaussian is fine". It means the data cannot tell.
- Forgetting to cite the original studies.

---

## Stage 4 — Manuscript rewrite (essential; 3–4 days)

Work on `manuscript/report.md` on the branch. Keep the v1.x text in git history.

**Structure**

1. **Introduction.** Meta-d′ and its hierarchical implementation; Rausch et al. on confounding; the untested assumption of a Gaussian signal distribution; Gumbel-min as a concrete alternative offered by `hmetad` (with its recognition-memory origin). State the four questions.
2. **Methods.** Generators (G0, G1, G2, G3-mix); fitting; diagnostics; metrics (Δ_mis, Δ_base, coverage); LOO plus grouped K-fold; targeted PPC; the empirical pipeline (inclusion, confidence rule, model specifications, classification). All pre-specified choices should reference `design_decisions.md` and commit hashes.
3. **Results.**
   - 3.1 Sanity and sensitivity: G0 calibration and G1 ordering (short).
   - 3.2 Consequences of misspecification: Δ_mis, d′ dependence, persistence, coverage.
   - 3.3 Detectability: LOO versus K-fold, targeted PPC.
   - 3.4 Difficulty-mixture control.
   - 3.5 Empirical prevalence and consequences.
4. **Discussion.** What analysts should do (compare families; inspect highest-confidence cells; model difficulty); relation to Rausch et al.; limitations; next steps.

**Main figures (maximum five)**
1. Design overview (update `fig_1_design.R`).
2. Δ_mis and Δ_base by N × T × d′, plus CrI width (Stage 1).
3. Detectability: the ΔELPD distribution, LOO versus K-fold agreement, and the targeted PPC detection rate.
4. Difficulty-mixture control (Stage 2b).
5. Empirical results (Stage 3).

G1 and the old Figs 5–7 move to the supplement if space is tight.

**Abstract (five moves, ≤ 250 words):** problem → simulation design → consequence (Δ_mis, coverage) → detectability → empirical prevalence. Write it **last**, from the numbers.

**Writing rules:** "was associated with / was consistent with"; every number traced to a CSV in `data/processed/`; limitations kept concrete (one misspecification family, a fixed log M, K-fold on a subset, database heterogeneity).

**Also update:** `README.md` (status, headline results, repository map incl. `code/06_empirical/`), `CITATION.cff` (version 2.0.0), `manuscript/references.bib` (add Rausch et al. 2023, Rahnev et al. 2020, the Gumbel-min memory paper, the original dataset papers), and `docs/deliverables_checklist.md`.

---

## Stage 5 — External feedback (useful; about 1 week, mostly waiting)

1. Send a short email with the PDF and repo link to the `hmetad` authors (the package is from the metacoglab group at UCL). Say what you found, and offer the Gumbel-min `stanvars` and the tests if useful to the package.
2. Ask one person in your programme with Bayesian or metacognition expertise for a critical read. Give them three questions:
   - Is the contribution clear relative to Rausch et al.?
   - Is anything overclaimed?
   - Which figure is least convincing?
3. Log every piece of feedback and your response in `docs/v3/feedback_log.md`.

---

## Stage 6 — Release, preprint and submission (1–2 days)

1. Merge `v2-enhancement` into `main` and tag `v2.0.0`. Enable the GitHub–Zenodo integration **before** tagging, so that the release gets a DOI.
2. Clean-environment check: in a fresh clone, run `renv::restore()`, then `make test`, then `make figures`. All must succeed.
3. Render the manuscript to PDF and upload it to PsyArXiv. Put the Zenodo DOI in the Data/Code Availability statement.
4. Choose a methods-oriented journal: read the aims and scope of 2–3 candidates and check each one's preprint policy. Submit the same version. Update the CV line to "Preprint (under review)" only once it has been submitted.
5. **CV line (draft):** *"Distributional misspecification in hierarchical meta-d′: a simulation and open-data study (preprint, 2026). R/Stan; 1,500+ Bayesian fits; code and data openly available."* Edit it to match the final numbers.

---

## Deferred (do **not** do before submission)

| Item | Reason |
|---|---|
| Unequal-variance Gaussian | `hmetad` documents that unequal variance and meta-d′ cannot be estimated together; it would need a new parameterisation |
| More dynamic confidence mechanisms | Dilutes the central question; Rausch et al. already cover mechanism variation |
| AUROC2 or other efficiency measures | A separate paper |
| More K values or true log M values | Low return relative to cost; list under Limitations |
| JAGS HMeta-d cross-check | Nice to have; list under Limitations |

Any of these may reappear **only** if a reviewer asks for it.

---

## Summary checklist

- [ ] 0.1 Branch, folders, `v3:` config block
- [ ] Stage 0 `positioning.md`: gate 0 passed
- [ ] Stage 1 relative-bias table and figure: gate 1 passed
- [ ] Stage 2.1 LOO reliability report
- [ ] Stage 2.2 K-fold (plan committed → one-fit test → 24 pairs): gate 2 decided
- [ ] Stage 2b difficulty-mixture control: gate 2b decided
- [ ] Stage 3.1 empirical plan committed (hash logged)
- [ ] 3.3 inventory · 3.4 confidence rule and tests · 3.5 wrapper extension and tests
- [ ] 3.7 pilot: gate 3 passed
- [ ] 3.8 main run and summary
- [ ] Stage 4 manuscript, README, CITATION, references
- [ ] Stage 5 feedback logged
- [ ] Stage 6 `v2.0.0` tag, Zenodo DOI, PsyArXiv, journal submission

## First 60–90 minute task

Read Rausch et al. (2023), Methods and Discussion. Fill in the four items of Stage 0, step 1 in `docs/v3/positioning.md`.
