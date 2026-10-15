# Project 1 v3b: Pre-submission reinforcement plan and coding guide

> **Status (2026-10-15): work packages B and C restarted; D (G4 unequal variance) remains paused (see `docs/deferred.md`).** Branch `v3b-confound`, created from `main` (`ccf73cf`); `v3-enhancement` has been merged and deleted, so wherever it is mentioned below, read `v3b-confound` instead. `config/v3b.yml` contains only the settings used by B and C (no `g4`); the grid generates only the 40 jobs for C.
>
> (Status on 2026-10-14: paused, to be restarted once a decision to submit was made; no part had been run at that point.)

> Scope: work added before and after the v3 empirical fits finish, in order to **submit smoothly in one go**.
> Principle: **anything a reviewer is likely to ask for that can be done in ≤ about 2 days is done now; everything else goes into `docs/deferred.md`.**
> Corresponding repo: `metacognitive-noise-recovery`, branch `v3-enhancement` (current HEAD = `dc2124c`).
> Written on 2026-10-02. All code is written against the repo's existing functions (`fit_one_hmetad()`, `simulate_g2_gumbel()`, the record format of `run_one_cell.R`, the sharding approach of `v3_sdprior_hetero_validation.R`).
> Places marked **⚠️ Check first** are details I could not actually run and verify on your Windows R; the first time you run them, look at the output before continuing.

---

## Contents

- [0. Overview](#0-overview)
- [1. Work package A: Preparation and pre-specification (half a day)](#1-work-package-a-preparation-and-pre-specification-half-a-day)
- [2. Work package B: False-positive re-analysis of the d′ confound (1 day, no new fits)](#2-work-package-b-false-positive-re-analysis-of-the-d-confound-1-day-no-new-fits)
- [3. Work package C: Two-group single-model test (1 day + background computing)](#3-work-package-c-two-group-single-model-test-1-day--background-computing)
- [4. Work package D: Unequal-variance generator G4 (1–1.5 days + background computing)](#4-work-package-d-unequal-variance-generator-g4-115-days--background-computing)
- [5. Work package E: Figures](#5-work-package-e-figures)
- [6. Work package F: Finalising the empirical analysis](#6-work-package-f-finishing-the-empirical-analysis)
- [7. Work package G: Writing](#7-work-package-g-writing)
- [8. Work package H: Pre-submission checklist and release](#8-work-package-h-pre-submission-checklist-and-release)
- [Appendix A: Troubleshooting common errors](#appendix-a-troubleshooting-common-errors)
- [Appendix B: Summary of decision points](#appendix-b-summary-of-decision-points)
- [Appendix C: Timeline](#appendix-c-timeline)

---

## 0. Overview

### 0.1 Work packages

| Package | Content | Which reviewer question it answers | New fits | Time |
|---|---|---|---|---|
| A | Config file, `deferred.md`, pre-specification tag | "Were these analyses added after seeing the results?" | No | Half a day |
| B | Use the existing 480 G2 fits to compute the false-positive rate when "each group is fitted separately" | "Does the bias have practical consequences?" | No | 1 day |
| C | Two groups (different d′, same log M) placed in **one model** to test the group difference | As above, using a formal between-group model | 40 | 1 day + 2–5 h |
| D | Unequal-variance Gaussian (UV) generator, to see whether LOO prefers Gumbel-min because of it | "Could the preference for Gumbel just be unequal variance?" | 80 | 1–1.5 days + 4–10 h |
| E | Figure 10 (main figure), Figure S (supplementary) | — | No | Half a day |
| F | Empirical: LOO fix → PPC → aggregation → Figure 9 | Main empirical results | Already running | Depends on computing |
| G | Positioning in the literature, effect-size benchmarks, UV discussion, comparison with Meyer-Grant, rewriting the paper | Novelty, scope of claims | No | 4–6 days |
| H | Required submission items, human read-through, v2.0.0, DOI, preprint, submission | Administration and quality | No | 2 days + waiting |

**Freeze point**: once the results of B, C and D are in and F is complete, **no further analyses are added**. Whatever the direction of the results, they are written into the paper using the pre-specified wording.

### 0.2 Fixed rules

1. **Branch**: keep working on `v3-enhancement`. Commit after each sub-step is completed.
2. **Do not modify `config/v3.yml` while shards are running**. All v3b constants go in the new file `config/v3b.yml`.
3. **Locations of new outputs** (none of them overwrite v1, v2 or v3 files):
   - `data/interim/v3b/`: the record of each fit (`.qs2` is already excluded by `.gitignore`)
   - `data/processed/v3b/`: small result tables, committed to Git
   - `outputs/figures/v3b/`
4. **Specify first, then run**: the decision rules in `config/v3b.yml` are committed and tagged `v3b-prereg` first, and only then is any v3b analysis run, including the re-analysis in B.
5. **Record an entry in `docs/analysis_log.md` for every step**: date, what was run, output file names, any deviations.
6. **Fit settings**: B, C and D are all simulations, so they use the **v1 production settings** (`config/design.yml`: default SD priors, non-hierarchical thresholds, 1000 + 1000, adapt_delta 0.95), the same as G2, so that the results can be compared directly with G2. **Do not** use the empirical settings.
7. **Sign conventions** (unified for v3b, already written into `config/v3b.yml`):
   - `diff_high_minus_low = log M(high-d′ group) − log M(low-d′ group)`; true value = 0. Same direction as `b_groupB` in C.
   - `elpd_diff = elpd(normal) − elpd(gumbel_min)`: positive = Gaussian preferred (as in v3).

### 0.3 Compute scheduling

The empirical fits currently use 4 shards with 4 chains each, 16 chains in total. This machine has 22 logical cores, so v3b **opens only 1 shard** (another 4 chains, 20 in total), running C first (jobs 1–40) and then D (jobs 41–120). A single shard runs jobs in job-number order, so C will finish first.

### 0.4 List of new files

```text
config/v3b.yml
config/grid_v3b.csv                                   # generated by a script
docs/v3b_plan.md                                      # this document
docs/deferred.md
docs/positioning.md                                   # work package G
code/00_setup/04_create_grid_v3b.R
code/01_simulate/simulate_v3b_two_group.R
code/01_simulate/simulate_g4_uv.R
code/02_fit/run_v3b_jobs.R
code/03_recovery_analysis/v3b_dprime_confound_reanalysis.R
code/04_ppc_and_comparison/v3b_two_group_summary.R
code/04_ppc_and_comparison/v3b_g4_summary.R
code/05_figures/fig_10_dprime_confound.R
code/05_figures/fig_S_g4_uv.R
tests/test_simulate_v3b_two_group.R
tests/test_simulate_g4_uv.R
```

---

## 1. Work package A: Preparation and pre-specification (half a day)

### 1.1 Confirm the starting point

```bash
cd metacognitive-noise-recovery
git status            # should show only renv.lock, v3_reloo_stored_fits.R (line endings only) and enhancement_plan_v2.md
git log --oneline -1  # dc2124c
mkdir -p data/processed/v3b data/interim/v3b outputs/figures/v3b
```

While you are at it, deal with `docs/enhancement_plan_v2.md`: add the line `> SUPERSEDED by docs/v3_plan.md and docs/v3b_plan.md; kept for the record.` at the very top of the file, then commit it together with the other files in 1.5.

### 1.2 `config/v3b.yml`

Full contents; create it directly:

```yaml
# v3b pre-submission additions (docs/v3b_plan.md). Locked before any v3b analysis
# (tag v3b-prereg). Simulation-only; fits use the v1 production settings in
# config/design.yml (same as G2), NOT the empirical configuration in config/v3.yml.
version: v3b
seed_base_v3b: 20261003

sign_conventions:
  diff_high_minus_low: "log_M(high-d' group) - log_M(low-d' group); truth = 0; same sign as b_groupB"
  elpd_diff: "elpd(normal) - elpd(gumbel_min); positive = Gaussian preferred (as in v3)"

# Work package B: spurious group differences when two groups that differ only in
# d' are fitted SEPARATELY (common practice), using the stored G2 fits.
reanalysis:
  interval: 0.95
  pair_seed_offset: 7              # seed for the random pairing of posterior draws
  statuses_primary: [pass, fail]   # as in v3 relative_bias.R; sensitivity = pass only

# Work package C: the same question in ONE model with a group covariate.
two_group:
  n_per_group: 20
  n_trials: 200
  dprime_groups: {A: 0.75, B: 1.5}  # A = low d', B = high d'; true log_M equal (design.yml truth)
  replications: 20
  fit_variants: [correct, misspecified]   # gumbel_min, normal

# Pre-specified framing rule for B + C (decides the headline wording, not whether
# the result is reported). "Practically relevant spurious-difference problem" if the
# misspecified false-positive rate is >= 0.20 in any N x T cell of B, OR its pooled
# rate exceeds the correct model's by >= 0.10 in B or in C.
framing_rule:
  cell_fpr_min: 0.20
  pooled_excess_min: 0.10

# Work package D: does unequal-variance Gaussian evidence make LOO prefer gumbel_min?
g4:
  n_participants: 40
  n_trials: 200
  dprimes: [0.75, 1.5]             # mean separation in units of the S1 (stimulus 0) SD
  sigma_ratio: {ev: 1.0, uv: 1.25} # SD(stimulus 1) / SD(stimulus 0); zROC slope = 1/ratio
  sigma_meta: 1.0                  # Gaussian noise added to the evidence before confidence
  conf_thresholds: [0.5, 1.0, 1.5] # distance from the criterion; K = 4
  sd_threshold_jitter: 0.1         # per-participant jitter of the confidence thresholds
  sd_criterion: 0.2                # per-participant type-1 criterion, mean 0
  replications: 10                 # ev and uv share sim_seed within (d', rep): paired datasets
  fit_variants: [normal, gumbel_min]
  # Pre-specified rule, mirrors the G3 artefact rule: "UV mimics gumbel_min" if,
  # pooled over d', LOO favours gumbel_min by > 2 SE in >= 25% of uv datasets AND
  # in <= 10% of ev datasets.
  mimicry_rule:
    uv_min_prop: 0.25
    ev_max_prop: 0.10
    two_se: 2
```

**Why these numbers**:
- The C cell uses N = 20 + 20, T = 200. This makes the total of 40 participants match G2's N = 40, and keeps the computational load small.
- D's `sigma_ratio = 1.25` corresponds to a zROC slope of 0.8, a common value in the recognition-memory literature; slopes in perceptual tasks are usually closer to 1, so 1.25 leans towards "a clear violation". This should be stated in the limitations.
- D does not assess recovery of the true log M, because this generator is not a meta-d′ model and the "true M" has no clear definition under UV. D only compares the differences between UV and the EV control.

### 1.3 `docs/deferred.md`

```markdown
# Deferred (do not start before submission; revisit only if a reviewer asks)

Rule: a new idea is written here first, never implemented the same day.

| Idea | Why deferred | Trigger to revisit |
|---|---|---|
| UV generator with other ratios (e.g. 0.8, 1.5) or fitting a UV model | v3b G4 answers the mimicry question with one ratio | Reviewer request |
| JAGS HMeta-d / MLE meta-d' cross-check | Different estimator, large new pipeline | Reviewer request |
| Other true log_M values, K != 4, more replications | Generalisation stated as a limitation | Reviewer request |
| K-fold for all G2 fits | Reloo on 24 pairs already agrees with PSIS (v3 step 2) | Reviewer request |
| More empirical datasets / dataset-by-dataset match with Meyer-Grant et al. | Qualitative comparison only (v3b G) | Reviewer request |
| New PPC statistics, new figures beyond Fig. 10 / Fig. S | Main-figure budget is five | Reviewer request |
```

### 1.4 Analysis log entry (template)

Add the following at the end of `docs/analysis_log.md`:

```markdown
## 2026-10-0X - v3b set-up: pre-submission additions, rules locked before any v3b analysis

- Plan: `docs/v3b_plan.md`. Constants and decision rules: `config/v3b.yml` (framing rule for
  the d' confound, G4 mimicry rule). Tag `v3b-prereg` placed on this commit before any v3b
  analysis was run.
- Already known before this commit (so not a pre-specified finding): the v3 step 1 d' contrast
  in Delta_mis (+0.097, SE 0.011, low minus high). Not yet computed: any false-positive rate
  for group comparisons, any two-group fit, any G4 fit.
- Fits in C and D use the v1 production settings (`config/design.yml`), matching G2.
- `docs/deferred.md` lists what is explicitly out of scope before submission.
```

### 1.5 Commit and tag

```bash
git add config/v3b.yml docs/v3b_plan.md docs/deferred.md docs/analysis_log.md docs/enhancement_plan_v2.md
git commit -m "v3b: plan, locked constants and decision rules (d' confound framing, G4 mimicry) before any v3b analysis"
git tag v3b-prereg
git push origin v3-enhancement --tags
```

### 1.6 Check for understanding

1. Why should C and D use the v1 fit settings rather than the empirical settings?
2. The d′ contrast in B (+0.097) is already known, so why still pre-specify? What exactly is being pre-specified?

---

## 2. Work package B: False-positive re-analysis of the d′ confound (1 day, no new fits)

### 2.1 Why

Each G2 cell was fitted separately. In practice, many studies also **fit each group separately** and then compare the two groups' log M (e.g. a patient group and a healthy group). If the two groups have the same true log M and differ only in d′, and the misspecification bias changes with d′, then the proportion of cases in which "the 95% CrI of the between-group log M difference excludes 0" is the **false-positive rate**. B answers this question directly using the existing 480 fits:

- Within the same (N, T, rep), the d′ = 0.75 cell is treated as the "low-d′ group" and the d′ = 1.5 cell as the "high-d′ group".
- The posteriors of the two fits are independent, so the posterior of the difference can be obtained by randomly pairing the draws from each side and subtracting.
- The same calculation with the correct model (Gumbel-min) serves as the baseline: the correct model itself may also have a small bias that changes with d′ (the negative bias in G0 is an example), so what is compared is **the difference between the two models' false-positive rates**, rather than simply comparing with 5%.

Each fit_variant has 6 N×T cells × 20 replications = 120 pairs.

### 2.2 `code/03_recovery_analysis/v3b_dprime_confound_reanalysis.R`

```r
# v3b work package B: false-positive rate for a between-group difference in log_M
# when two groups differ ONLY in d' and each group is fitted separately.
# Uses the stored G2 fits (draws_b_sd$b_Intercept). No refitting.
# Low-d' group = d' 0.75 cell, high-d' group = d' 1.5 cell, same (N, T, rep, fit_variant).
# diff_high_minus_low: truth = 0 (both cells share log_M = design.yml truth).
#
# Run from the project root: Rscript code/03_recovery_analysis/v3b_dprime_confound_reanalysis.R

suppressPackageStartupMessages(library(dplyr))

cfgb <- yaml::read_yaml(here::here("config", "v3b.yml"))
ra   <- cfgb$reanalysis
out  <- here::here("data", "processed", "v3b")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

# ---- Locate the 480 G2 records ---------------------------------------------
grid <- readr::read_csv(here::here("config", "grid.csv"), show_col_types = FALSE) |>
  filter(generator == "g2")
grid$path <- here::here("data", "interim", sprintf(
  "g2_cell-%04d_rep-%02d_%s_grid-%05d.qs2",
  grid$cell_id, grid$rep_id, grid$fit_variant, grid$grid_id))
stopifnot(nrow(grid) == 480, all(file.exists(grid$path)))

# ---- Read status + log_M draws (compact record, every rep) -----------------
recs <- lapply(grid$path, function(p) {
  r <- qs2::qs_read(p)
  list(status = r$status,
       x = if (is.null(r$draws_b_sd)) NULL else r$draws_b_sd$b_Intercept)
})
grid$status  <- vapply(recs, function(r) r$status, character(1))
grid$n_draws <- vapply(recs, function(r) length(r$x), integer(1))
draws <- setNames(lapply(recs, `[[`, "x"), grid$grid_id)
cat("status counts:\n"); print(table(grid$fit_variant, grid$status))

# ---- Pair low-d' and high-d' cells -------------------------------------------
keys <- c("fit_variant", "n_participants", "n_trials", "rep_id")
lev  <- grid |> select(grid_id, all_of(keys), dprime_target, status, n_draws)
pairs <- inner_join(filter(lev, dprime_target == 0.75), filter(lev, dprime_target == 1.5),
                    by = keys, suffix = c("_low", "_high"))
stopifnot(nrow(pairs) == 240)

# ---- Posterior of the difference, per pair ----------------------------------
set.seed(cfgb$seed_base_v3b + ra$pair_seed_offset)
lo_p <- (1 - ra$interval) / 2
by_pair <- pairs |>
  mutate(diff_mean = NA_real_, diff_q_lo = NA_real_, diff_q_hi = NA_real_, excl0 = NA)
for (i in seq_len(nrow(by_pair))) {
  a <- draws[[as.character(by_pair$grid_id_low[i])]]
  b <- draws[[as.character(by_pair$grid_id_high[i])]]
  if (is.null(a) || is.null(b)) next
  n <- min(length(a), length(b))
  d <- sample(b, n) - sample(a, n)                 # high minus low; independent posteriors
  q <- stats::quantile(d, c(lo_p, 1 - lo_p), names = FALSE)
  by_pair$diff_mean[i] <- mean(d)
  by_pair$diff_q_lo[i] <- q[1]; by_pair$diff_q_hi[i] <- q[2]
  by_pair$excl0[i]     <- q[1] > 0 | q[2] < 0
}
by_pair <- by_pair |>
  mutate(primary   = status_low %in% ra$statuses_primary & status_high %in% ra$statuses_primary,
         pass_only = status_low == "pass" & status_high == "pass")
readr::write_csv(by_pair, file.path(out, "b_dprime_confound_by_pair.csv"))

# ---- Summaries ---------------------------------------------------------------
wilson <- function(k, n, z = 1.96) {
  p <- k / n; den <- 1 + z^2 / n
  ctr <- (p + z^2 / (2 * n)) / den
  hw  <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den
  c(ctr - hw, ctr + hw)
}
# Output columns are named mean_diff / mcse_diff (not diff_mean): inside summarise(),
# re-using an input column name would make later expressions see the summarised value.
summarise_fpr <- function(d, ...) d |>
  group_by(...) |>
  summarise(n = n(), k = sum(excl0), fpr = k / n,
            fpr_lo = wilson(k, n)[1], fpr_hi = wilson(k, n)[2],
            mean_diff = mean(diff_mean), mcse_diff = sd(diff_mean) / sqrt(n()),
            prop_diff_neg = mean(diff_mean < 0),
            .groups = "drop")

prim <- filter(by_pair, primary, !is.na(excl0))
sens <- filter(by_pair, pass_only, !is.na(excl0))

by_cell <- bind_rows(
  summarise_fpr(prim, fit_variant, n_participants, n_trials) |> mutate(analysis = "primary"),
  summarise_fpr(sens, fit_variant, n_participants, n_trials) |> mutate(analysis = "pass_only"))
pooled <- bind_rows(
  summarise_fpr(prim, fit_variant) |> mutate(analysis = "primary"),
  summarise_fpr(sens, fit_variant) |> mutate(analysis = "pass_only"))
readr::write_csv(by_cell, file.path(out, "b_dprime_confound_by_cell.csv"))
readr::write_csv(pooled,  file.path(out, "b_dprime_confound_pooled.csv"))

# Paired on the same simulated datasets: which variant produced the false positive?
paired <- prim |>
  select(n_participants, n_trials, rep_id, fit_variant, excl0) |>
  tidyr::pivot_wider(names_from = fit_variant, values_from = excl0) |>
  count(correct, misspecified, name = "n_pairs")
readr::write_csv(paired, file.path(out, "b_dprime_confound_paired.csv"))

# ---- Pre-specified framing rule (config/v3b.yml framing_rule) --------------
fr <- cfgb$framing_rule
cell_max_mis <- max(by_cell$fpr[by_cell$analysis == "primary" & by_cell$fit_variant == "misspecified"])
p_mis <- pooled$fpr[pooled$analysis == "primary" & pooled$fit_variant == "misspecified"]
p_cor <- pooled$fpr[pooled$analysis == "primary" & pooled$fit_variant == "correct"]
verdict_B <- cell_max_mis >= fr$cell_fpr_min || (p_mis - p_cor) >= fr$pooled_excess_min
writeLines(c(sprintf("max cell FPR (misspecified) = %.3f", cell_max_mis),
             sprintf("pooled FPR misspecified = %.3f, correct = %.3f, excess = %.3f", p_mis, p_cor, p_mis - p_cor),
             sprintf("framing rule met in B: %s", verdict_B)),
           file.path(out, "b_framing_rule.txt"))

cat("\n=== Pooled ===\n"); print(as.data.frame(pooled), digits = 3)
cat("\n=== By cell (primary) ===\n"); print(as.data.frame(filter(by_cell, analysis == "primary")), digits = 3)
cat("\n=== Paired ===\n"); print(paired)
cat("\nframing rule met in B:", verdict_B, "\n")
```

### 2.3 Running and checking

```bash
Rscript code/03_recovery_analysis/v3b_dprime_confound_reanalysis.R
```

Sanity checks (estimated from known results; these are not targets to hit):

| Check | Expected | If not |
|---|---|---|
| `status counts` | Only a few `fail` out of 480, no `error` | If there is an `error`, first find out which file it is |
| `n_draws` for each fit | 4000 | If it is not 4000, check whether `draws_b_sd` has been truncated |
| `mean_diff` for misspecified | Negative, about −0.10 (because Δ_mis is larger at low d′, high minus low is negative) | A positive value means the pairing direction is reversed |
| `mean_diff` for correct | Close to 0, possibly with a small systematic bias | Do not change the code just because it is not close to 0; this is exactly why it is compared with misspecified |
| Size of `fpr` | Expected to be highest in the T = 400 cells (narrowest posteriors, bias still present) | If T = 100 is highest, first check whether `interval` was read as 0.5 |

### 2.4 Check for understanding (write into the analysis log)

1. Why can the draws from the two cells be randomly paired and subtracted? If the two fits used **the same** data, would this still be correct?
2. Why should the "false-positive rate" be compared with the correct model rather than with 0.05?
3. If the misspecified FPR is highest at T = 400, how does this relate to the "increasingly confidently wrong" finding from v3 step 1?

### 2.5 Commit

```bash
git add code/03_recovery_analysis/v3b_dprime_confound_reanalysis.R data/processed/v3b/b_* docs/analysis_log.md
git commit -m "v3b B: false-positive rate for group differences under separate fits (stored G2 fits, no refitting)"
```

---

## 3. Work package C: Two-group single-model test (1 day + background computing)

### 3.1 Why

B uses "each group fitted separately", and a reviewer will ask: if the two groups are placed in **one hierarchical model** with a group covariate (the approach recommended by most methods papers), do the false positives persist? C answers this question:

- Data: group A has 20 participants with d′ = 0.75; group B has 20 participants with d′ = 1.5; log M is −1 in both groups; the data are generated by Gumbel-min.
- Model: log M, d′ and c all receive a `group` covariate; the key parameter is **`b_groupB`** (the log M difference, group B minus group A; true value = 0).
- Two fits: `correct` (Gumbel-min) and `misspecified` (Gaussian), on the same data.

### 3.2 `code/01_simulate/simulate_v3b_two_group.R`

```r
# v3b work package C: two groups of participants that differ ONLY in d'
# (same true log_M), simulated from the gumbel_min generator used for G2.
# Group B participants get ids offset by the size of group A, so ids are unique.
# Requires code/01_simulate/simulate_g2_gumbel.R to be sourced first.

simulate_two_group_g2 <- function(n_per_group, n_trials, dprime_groups, log_M,
                                  k = 4, seed) {
  stopifnot(all(c("A", "B") %in% names(dprime_groups)))
  a <- simulate_g2_gumbel(n_per_group, n_trials, dprime_groups[["A"]], log_M, k = k, seed = seed)
  b <- simulate_g2_gumbel(n_per_group, n_trials, dprime_groups[["B"]], log_M, k = k,
                          seed = seed + 100000L)
  a$participant <- as.integer(a$participant)
  b$participant <- as.integer(b$participant) + max(a$participant)
  a$group <- "A"; b$group <- "B"
  out <- dplyr::bind_rows(a, b)
  out$group <- factor(out$group, levels = c("A", "B"))
  out
}
```

⚠️ **Check first**: the type of the `participant` column output by `hmetad::sim_metad_participant()`. Run in the R console:

```r
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
d <- simulate_g2_gumbel(3, 20, 1, -1, seed = 1); str(d$participant); head(d)
```

If `participant` is a factor and its levels are not 1, 2, 3…, `as.integer()` will turn it into the level index, which is still unique, so that is fine; but please confirm that the columns in `head(d)` include `stimulus`, `response` and `confidence`.

### 3.3 `tests/test_simulate_v3b_two_group.R`

```r
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "01_simulate", "simulate_v3b_two_group.R"))

test_that("two groups, unique participant ids, balanced sizes", {
  d <- simulate_two_group_g2(5, 40, c(A = 0.75, B = 1.5), log_M = -1, seed = 11)
  expect_setequal(levels(d$group), c("A", "B"))
  ids <- tapply(d$participant, d$group, function(x) sort(unique(x)))
  expect_length(intersect(ids$A, ids$B), 0)
  expect_equal(length(unique(d$participant)), 10)
})

test_that("the high-d' group is more accurate", {
  d <- simulate_two_group_g2(20, 200, c(A = 0.75, B = 1.5), log_M = -1, seed = 12)
  acc <- tapply(d$stimulus == d$response, d$group, mean)
  expect_gt(acc[["B"]], acc[["A"]])
})
```

### 3.4 `code/00_setup/04_create_grid_v3b.R` (shared by C and D)

```r
# v3b job table for work packages C (two_group) and D (g4). Run once.
cfgb <- yaml::read_yaml(here::here("config", "v3b.yml"))
b <- as.integer(cfgb$seed_base_v3b)

tg <- tidyr::expand_grid(rep_id = seq_len(cfgb$two_group$replications),
                         fit_variant = unlist(cfgb$two_group$fit_variants)) |>
  dplyr::mutate(study = "two_group", condition = "g2", dprime = NA_real_,
                sim_seed = b + 10000L + rep_id)            # same data for both variants

dps <- unlist(cfgb$g4$dprimes)
g4 <- tidyr::expand_grid(dprime = dps, condition = names(cfgb$g4$sigma_ratio),
                         rep_id = seq_len(cfgb$g4$replications),
                         fit_variant = unlist(cfgb$g4$fit_variants)) |>
  dplyr::mutate(study = "g4",
                # ev and uv share the seed within (d', rep): paired datasets (same stimuli,
                # same standard-normal draws, only the S2 SD differs)
                sim_seed = b + 20000L + match(dprime, dps) * 1000L + rep_id)

grid <- dplyr::bind_rows(tg, g4) |>
  dplyr::mutate(job_id = dplyr::row_number(), fit_seed = sim_seed + 1000000L) |>
  dplyr::select(job_id, study, condition, dprime, rep_id, fit_variant, sim_seed, fit_seed)

stopifnot(nrow(grid) == 2 * cfgb$two_group$replications +
                         length(dps) * 2 * cfgb$g4$replications * 2)   # 40 + 80
readr::write_csv(grid, here::here("config", "grid_v3b.csv"))
print(dplyr::count(grid, study, condition, fit_variant))
```

```bash
Rscript code/00_setup/04_create_grid_v3b.R
```

Expected: 40 rows for two_group (jobs 1–40), 80 rows for g4 (jobs 41–120).

### 3.5 `code/02_fit/run_v3b_jobs.R` (runner shared by C and D)

This script cannot run D's jobs until work package D's `simulate_g4_uv.R` has also been written, but C's jobs can run first: the script only calls the G4 simulator when it is needed.

```r
# v3b runner for work packages C (two_group) and D (g4). Resumable, shardable.
# Usage: Rscript code/02_fit/run_v3b_jobs.R <job_id>
#        Rscript code/02_fit/run_v3b_jobs.R --shard <s> <n>
# Fits use the v1 production settings (config/design.yml), matching G2.

suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "01_simulate", "simulate_v3b_two_group.R"))
g4_file <- here::here("code", "01_simulate", "simulate_g4_uv.R")
if (file.exists(g4_file)) source(g4_file)
source(here::here("code", "02_fit", "extract_fit_summary.R"))
source(here::here("code", "02_fit", "fit_hmetad.R"))

cfg  <- yaml::read_yaml(here::here("config", "design.yml"))
cfgb <- yaml::read_yaml(here::here("config", "v3b.yml"))
grid <- readr::read_csv(here::here("config", "grid_v3b.csv"), show_col_types = FALSE)
out_dir <- here::here("data", "interim", "v3b")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

args <- commandArgs(trailingOnly = TRUE)
ids <- if (length(args) >= 3 && args[1] == "--shard") {
  s <- as.integer(args[2]); n <- as.integer(args[3])
  grid$job_id[(grid$job_id - 1L) %% n == (s - 1L)]
} else as.integer(args[1])
stopifnot(length(ids) >= 1, all(ids %in% grid$job_id))

simulate_job <- function(row) {
  if (row$study == "two_group") {
    tg <- cfgb$two_group
    simulate_two_group_g2(tg$n_per_group, tg$n_trials, unlist(tg$dprime_groups),
                          log_M = cfg$truth$log_M, k = cfg$confidence$k, seed = row$sim_seed)
  } else if (row$study == "g4") {
    if (!exists("simulate_g4_uv")) stop("simulate_g4_uv.R not written yet (work package D)")
    g4 <- cfgb$g4
    simulate_g4_uv(g4$n_participants, g4$n_trials, dprime = row$dprime,
                   sigma_ratio = g4$sigma_ratio[[row$condition]], sigma_meta = g4$sigma_meta,
                   conf_thresholds = unlist(g4$conf_thresholds),
                   sd_threshold_jitter = g4$sd_threshold_jitter,
                   sd_criterion = g4$sd_criterion, seed = row$sim_seed)
  } else stop("unknown study: ", row$study)
}

fit_job <- function(row, data) {
  dist <- if (row$fit_variant %in% c("correct", "gumbel_min")) "gumbel_min" else "normal"
  two  <- row$study == "two_group"
  once <- function(adapt_delta, max_treedepth, seed) fit_one_hmetad(
    data, K = cfg$confidence$k, group = "participant",
    distribution = dist, metac_absolute = cfg$fitting$metac_absolute,
    hierarchical_dprime_c = cfg$fitting$hierarchical_dprime_c,
    hierarchical_thresholds = cfg$fitting$hierarchical_thresholds,
    log_M_prior = cfg$priors$log_M_production, metac2_prior = cfg$priors$metac2_gap,
    agg_by = if (two) "group" else NULL,
    dprime_c_covariates = if (two) "group" else NULL,
    log_M_covariates = if (two) "group" else NULL,
    chains = cfg$sampling$chains, warmup = cfg$sampling$warmup,
    iter_sampling = cfg$sampling$iter_sampling,
    adapt_delta = adapt_delta, max_treedepth = max_treedepth,
    rhat_max = cfg$diagnostics$rhat_max, bulk_ess_min = cfg$diagnostics$bulk_ess_min,
    tail_ess_min = cfg$diagnostics$tail_ess_min, seed = seed,
    extra_stanvars = if (dist == "gumbel_min") gumbel_min_stanvars() else NULL,
    metadata = row)
  a <- once(cfg$sampling$adapt_delta, cfg$sampling$max_treedepth, row$fit_seed)
  a$escalated <- FALSE
  if (identical(a$status, "refit")) {
    a <- once(cfg$sampling$escalation$adapt_delta, cfg$sampling$escalation$max_treedepth,
              row$fit_seed + 1L)
    a$escalated <- TRUE
    if (identical(a$status, "refit")) a$status <- "fail"
  }
  a
}

for (id in ids) {
  row <- as.list(grid[grid$job_id == id, ])
  out_path <- file.path(out_dir, sprintf("%s_%s_d%s_rep-%02d_%s_job-%03d.qs2",
                                         row$study, row$condition,
                                         ifelse(is.na(row$dprime), "NA", format(row$dprime)),
                                         row$rep_id, row$fit_variant, id))
  if (file.exists(out_path)) { cat("exists", id, "\n"); next }
  t0 <- Sys.time()
  rec <- tryCatch({
    data <- simulate_job(row)
    stopifnot(max(data$confidence) <= cfg$confidence$k)
    a <- fit_job(row, data)
    if (!is.null(a$fit)) {
      dr <- posterior::as_draws_df(a$fit)
      a$draws_b_sd <- tibble::as_tibble(dr[, grep("^b_|^sd_", names(dr), value = TRUE)])
      if (row$study == "g4") a$loo <- tryCatch(brms::loo(a$fit), error = function(e) NULL)
    }
    a$fit <- NULL                       # compact record only
    a
  }, error = function(e) list(status = "error", error_message = conditionMessage(e)))
  rec$job <- row
  qs2::qs_save(rec, out_path)
  cat(sprintf("job %3d %-9s %-3s %-12s rep %2d: %s (%.0f s)\n", id, row$study, row$condition,
              row$fit_variant, row$rep_id, rec$status,
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
```

### 3.6 Trial run (important)

```bash
Rscript -e 'testthat::test_file("tests/test_simulate_v3b_two_group.R")'
Rscript code/02_fit/run_v3b_jobs.R 1     # two_group, rep 1, correct
Rscript code/02_fit/run_v3b_jobs.R 2     # two_group, rep 1, misspecified
```

Open one of the records in the R console and **check the parameter names**:

```r
r <- qs2::qs_read(list.files("data/interim/v3b", "job-001", full.names = TRUE))
r$status; grep("group", names(r$draws_b_sd), value = TRUE)
```

⚠️ **Check first**: you should expect to see `b_groupB` (the group effect on log M), `b_dprime_groupB` and `b_c_groupB`. If the names differ (e.g. `b_groupB` does not exist), change `"b_groupB"` in the summary script in 3.7 to the actual name, and record this in the analysis log.

Once the trial run succeeds, start **one** shard in the background (C's 40 jobs will finish first, followed by D; if D's simulator has not been written yet, D's jobs will end with `error` and a record will be written).

⚠️ Because error records are also treated as "completed" and skipped, **do not let the shard reach job 41 before D's simulator has been written**. Approach: run only C's jobs first.

```bash
# PowerShell: run jobs 3-40 sequentially in one terminal
for ($i = 3; $i -le 40; $i++) { Rscript code/02_fit/run_v3b_jobs.R $i }
```

### 3.7 `code/04_ppc_and_comparison/v3b_two_group_summary.R`

```r
# v3b work package C summary: false-positive rate for b_groupB (log_M difference,
# truth 0) when two groups differ only in d', fitted in ONE model.
suppressPackageStartupMessages(library(dplyr))
cfgb <- yaml::read_yaml(here::here("config", "v3b.yml"))
out  <- here::here("data", "processed", "v3b")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

files <- list.files(here::here("data", "interim", "v3b"), "^two_group_.*[.]qs2$", full.names = TRUE)
stopifnot(length(files) == 2 * cfgb$two_group$replications)

param <- "b_groupB"   # CHECK against the trial fit (section 3.6)
by_fit <- purrr::map_dfr(files, function(f) {
  r <- qs2::qs_read(f); j <- r$job
  x <- if (!is.null(r$draws_b_sd) && param %in% names(r$draws_b_sd)) r$draws_b_sd[[param]] else NA_real_
  q <- stats::quantile(x, c(.025, .975), names = FALSE, na.rm = TRUE)
  tibble::tibble(job_id = j$job_id, rep_id = j$rep_id, fit_variant = j$fit_variant,
                 status = r$status, escalated = isTRUE(r$escalated),
                 diff_mean = mean(x), diff_q025 = q[1], diff_q975 = q[2],
                 excl0 = q[1] > 0 | q[2] < 0,
                 logM_groupA = if (is.null(r$draws_b_sd)) NA_real_ else mean(r$draws_b_sd$b_Intercept))
})
readr::write_csv(by_fit, file.path(out, "c_two_group_by_fit.csv"))

wilson <- function(k, n, z = 1.96) {
  p <- k / n; den <- 1 + z^2 / n; ctr <- (p + z^2 / (2 * n)) / den
  hw <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den; c(ctr - hw, ctr + hw)
}
summ <- function(d, label) d |>
  filter(!is.na(excl0)) |>
  group_by(fit_variant) |>
  summarise(n = n(), n_pass = sum(status == "pass"), k = sum(excl0), fpr = k / n,
            fpr_lo = wilson(k, n)[1], fpr_hi = wilson(k, n)[2],
            mean_diff = mean(diff_mean), mcse_diff = sd(diff_mean) / sqrt(n()),
            .groups = "drop") |>
  mutate(analysis = label)
pooled <- bind_rows(summ(filter(by_fit, status %in% c("pass", "fail")), "primary"),
                    summ(filter(by_fit, status == "pass"), "pass_only"))
readr::write_csv(pooled, file.path(out, "c_two_group_summary.csv"))

paired <- by_fit |> filter(status %in% c("pass", "fail")) |>
  select(rep_id, fit_variant, excl0) |>
  tidyr::pivot_wider(names_from = fit_variant, values_from = excl0) |>
  count(correct, misspecified, name = "n_reps")
readr::write_csv(paired, file.path(out, "c_two_group_paired.csv"))

fr <- cfgb$framing_rule
p_mis <- pooled$fpr[pooled$analysis == "primary" & pooled$fit_variant == "misspecified"]
p_cor <- pooled$fpr[pooled$analysis == "primary" & pooled$fit_variant == "correct"]
verdict_C <- (p_mis - p_cor) >= fr$pooled_excess_min
writeLines(sprintf("C: FPR misspecified = %.3f, correct = %.3f, excess = %.3f; framing rule met in C: %s",
                   p_mis, p_cor, p_mis - p_cor, verdict_C),
           file.path(out, "c_framing_rule.txt"))
print(as.data.frame(pooled), digits = 3); print(paired)
cat("framing rule met in C:", verdict_C, "\n")
```

### 3.8 Interpretation (pre-specified wording)

`framing_rule` is met if it holds in B **or** C:

| Result | How the paper's main message is worded |
|---|---|
| Rule met | "The bias caused by misspecifying the signal distribution changes with d′, and therefore produces **spurious log M differences** between groups that differ in d′." Presented as one of the main findings, in a main figure |
| Rule not met | "The bias is mainly a shift common to all groups; between-group comparisons are broadly robust, but **absolute** log M values (e.g. comparisons with 1, or comparisons across studies) are affected." Also a useful conclusion, in a main figure but with cautious wording |

**Both outcomes must be reported**; neither may be dropped because the result is not striking.

### 3.9 Check for understanding

1. Why is the true value of `b_groupB` 0? If the false-positive rate of the correct model (Gumbel-min) in C is also clearly above 5%, what might be the reason?
2. Why should d′ and c also receive the `group` covariate? What would happen if it were added only to log M?

### 3.10 Commit

```bash
git add code/01_simulate/simulate_v3b_two_group.R tests/test_simulate_v3b_two_group.R \
        code/00_setup/04_create_grid_v3b.R config/grid_v3b.csv code/02_fit/run_v3b_jobs.R \
        code/04_ppc_and_comparison/v3b_two_group_summary.R data/processed/v3b/c_* docs/analysis_log.md
git commit -m "v3b C: two-group single-model test of a spurious log_M difference (40 fits)"
```

(You can commit the code once when the scripts are written and the trial run succeeds, and then commit the results again once they are in.)

---

## 4. Work package D: unequal-variance generator G4 (1–1.5 days + background computing)

### 4.1 Rationale and design

If the empirical data favour Gumbel-min, reviewers will certainly ask: "Could this simply be because the signal variances are unequal?" Gumbel-min and the unequal-variance Gaussian (UV) both make the ROC asymmetric. D answers only one question: **do UV data make LOO favour Gumbel-min?**

Design:
- Generator: S1 evidence ~ N(−d′/2, 1), S2 evidence ~ N(+d′/2, σ). EV control condition σ = 1, UV condition σ = 1.25.
- Response: answer 1 when evidence > that participant's criterion c_j.
- Confidence: add a further noise term ε ~ N(0, σ_meta) to the evidence, and bin "how far it lies from the criterion in the chosen direction" into 4 levels. This makes metacognition imperfect, which is closer to real data.
- **Pairing**: for the same (d′, rep), EV and UV use the same seed, so the stimuli, criteria and all standard normal random numbers are identical; only the SD of S2 differs. Almost all of the difference between the two conditions comes from the variance, and Monte Carlo noise is very small.
- Each dataset is fitted twice: Gaussian and Gumbel-min. 2 d′ × 2 conditions × 10 replications × 2 fits = 80 fits.

Results reported by D:
1. Proportion of datasets in which LOO favours Gumbel-min (> 2 SE): UV versus EV, applying the pre-specified `mimicry_rule`.
2. UV-induced shift in log M: within the same pair, log M(UV) − log M(EV) from the Gaussian fit.
3. Family gap: log M(normal) − log M(gumbel), under EV and under UV separately.

### 4.2 `code/01_simulate/simulate_g4_uv.R`

```r
# G4 (v3b work package D): Gaussian signal detection with UNEQUAL variance plus
# Gaussian metacognitive noise, generated outside hmetad. This is NOT the meta-d'
# generative model, so it has no "true log_M"; G4 is analysed only as a paired
# contrast between ev (sigma_ratio = 1) and uv (sigma_ratio != 1) datasets that
# share a seed. "dprime" = mean separation in units of the stimulus-0 SD.
#
# Trial: stimulus s in {0, 1} (exactly n_trials/2 each, shuffled);
#   x ~ N(-d/2, 1) if s = 0, N(+d/2, sigma_ratio) if s = 1   (drawn as mu + sd * z)
#   response = 1 if x > c_j
#   y = x + N(0, sigma_meta);  dist = (y - c_j) * (2 * response - 1)
#   confidence = 1 + number of thresholds below dist  (dist < first threshold -> 1)

simulate_g4_uv <- function(n_participants, n_trials, dprime, sigma_ratio, sigma_meta,
                           conf_thresholds, sd_threshold_jitter = 0.1,
                           sd_criterion = 0.2, seed) {
  stopifnot(n_trials %% 2 == 0, sigma_ratio > 0, sigma_meta >= 0,
            !is.unsorted(conf_thresholds))
  withr::with_seed(seed, {
    purrr::map_dfr(seq_len(n_participants), function(j) {
      stim <- sample(rep(0:1, each = n_trials / 2))
      z_x  <- stats::rnorm(n_trials)                       # common random numbers:
      z_m  <- stats::rnorm(n_trials)                       # identical across sigma_ratio
      c_j  <- stats::rnorm(1, 0, sd_criterion)
      thr  <- sort(conf_thresholds + stats::rnorm(length(conf_thresholds), 0, sd_threshold_jitter))
      mu   <- ifelse(stim == 1, dprime / 2, -dprime / 2)
      sdv  <- ifelse(stim == 1, sigma_ratio, 1)
      x    <- mu + sdv * z_x
      resp <- as.integer(x > c_j)
      y    <- x + sigma_meta * z_m
      dist <- (y - c_j) * (2 * resp - 1)
      conf <- 1L + findInterval(dist, thr)
      tibble::tibble(participant = j, trial = seq_len(n_trials), stimulus = as.integer(stim),
                     response = resp, confidence = as.integer(conf),
                     correct = as.integer(stim == resp))
    })
  })
}

# Slope of the type-1 zROC built from the 2K-point rating scale (response x confidence).
# Used by the tests: with sigma_meta = 0 the slope is exactly 1 / sigma_ratio.
zroc_slope <- function(d, K) {
  rating <- ifelse(d$response == 1, K + d$confidence, K + 1L - d$confidence)
  cuts <- 2:(2 * K)
  hr  <- vapply(cuts, function(k) mean(rating[d$stimulus == 1] >= k), numeric(1))
  far <- vapply(cuts, function(k) mean(rating[d$stimulus == 0] >= k), numeric(1))
  ok  <- hr > 0 & hr < 1 & far > 0 & far < 1
  unname(stats::coef(stats::lm(stats::qnorm(hr[ok]) ~ stats::qnorm(far[ok])))[2])
}
```

**Why `z_x` and `z_m` are drawn separately**: this way EV and UV use exactly the same random numbers under the same seed; only the S2 evidence is multiplied by a different SD. If you switched to interleaved draws with `rnorm(n, mu, sd)`, the two conditions would still be paired, but writing it as a standard normal multiplied by the SD is clearer and easier to check.

### 4.3 `tests/test_simulate_g4_uv.R`

```r
source(here::here("code", "01_simulate", "simulate_g4_uv.R"))
thr <- c(0.5, 1.0, 1.5)

test_that("coding, balance and K", {
  d <- simulate_g4_uv(5, 100, 1, 1, 1, thr, seed = 1)
  expect_true(all(d$stimulus %in% 0:1))
  expect_true(all(d$response %in% 0:1))
  expect_true(all(d$confidence %in% 1:4))
  expect_equal(as.vector(table(d$participant, d$stimulus)), rep(50L, 10))
})

test_that("zROC slope equals 1 / sigma_ratio without metacognitive noise", {
  for (s in c(1, 1.25)) {
    d <- simulate_g4_uv(1, 200000, 1.5, s, 0, thr, sd_threshold_jitter = 0,
                        sd_criterion = 0, seed = 2)
    expect_equal(zroc_slope(d, 4), 1 / s, tolerance = 0.03)
  }
})

test_that("ev and uv with the same seed are paired", {
  e <- simulate_g4_uv(3, 100, 1, 1.00, 1, thr, seed = 3)
  u <- simulate_g4_uv(3, 100, 1, 1.25, 1, thr, seed = 3)
  expect_identical(e$stimulus, u$stimulus)
  expect_identical(e$response[e$stimulus == 0], u$response[u$stimulus == 0])  # S1 trials identical
  expect_gt(mean(e$response == u$response), 0.9)
})

test_that("every confidence level is used at production settings", {
  for (dp in c(0.75, 1.5)) for (s in c(1, 1.25)) {
    d <- simulate_g4_uv(40, 200, dp, s, 1, thr, seed = 4)
    expect_true(all(prop.table(table(factor(d$confidence, levels = 1:4))) > 0.05))
  }
})

test_that("accuracy rises with d'", {
  lo <- mean(simulate_g4_uv(40, 200, 0.75, 1, 1, thr, seed = 5)$correct)
  hi <- mean(simulate_g4_uv(40, 200, 1.50, 1, 1, thr, seed = 5)$correct)
  expect_gt(hi, lo)
})
```

```bash
Rscript -e 'testthat::test_file("tests/test_simulate_g4_uv.R")'
```

**If the "every confidence level > 5%" test fails**: this means `conf_thresholds` is not suitable for this evidence scale. You may adjust `conf_thresholds` in `config/v3b.yml` only **before submitting any G4 fits**; record it in the analysis log, commit, and then run. This counts as generator calibration, not a change made after seeing results, but it must still be recorded.

Also do one visual check (not part of the tests):

```r
d_ev <- simulate_g4_uv(40, 200, 1.5, 1.00, 1, c(.5, 1, 1.5), seed = 9)
d_uv <- simulate_g4_uv(40, 200, 1.5, 1.25, 1, c(.5, 1, 1.5), seed = 9)
c(ev = zroc_slope(d_ev, 4), uv = zroc_slope(d_uv, 4))   # expect uv < ev
prop.table(table(d_uv$confidence))
```

### 4.4 Running

After C's 40 jobs have finished (or at least after confirming that jobs 1–2 are fine):

```bash
Rscript code/02_fit/run_v3b_jobs.R 41      # g4, d' 0.75, ev, rep 1, normal
Rscript code/02_fit/run_v3b_jobs.R 42      # same dataset, gumbel_min
```

Check `status` and `loo` (not NULL) in both records:

```r
r <- qs2::qs_read(list.files("data/interim/v3b", "job-041", full.names = TRUE)); r$status; class(r$loo)
```

If everything looks fine, run the rest in order:

```powershell
for ($i = 43; $i -le 120; $i++) { Rscript code/02_fit/run_v3b_jobs.R $i }
```

### 4.5 `code/04_ppc_and_comparison/v3b_g4_summary.R`

```r
# v3b work package D summary: does unequal-variance evidence make LOO prefer gumbel_min?
suppressPackageStartupMessages(library(dplyr))
cfgb <- yaml::read_yaml(here::here("config", "v3b.yml")); g4 <- cfgb$g4
out  <- here::here("data", "processed", "v3b")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

files <- list.files(here::here("data", "interim", "v3b"), "^g4_.*[.]qs2$", full.names = TRUE)
stopifnot(length(files) == length(unlist(g4$dprimes)) * 2 * g4$replications * 2)
recs <- lapply(files, qs2::qs_read)

by_fit <- purrr::map_dfr(recs, function(r) {
  j <- r$job
  x <- if (is.null(r$draws_b_sd)) NA_real_ else r$draws_b_sd$b_Intercept
  tibble::tibble(job_id = j$job_id, dprime = j$dprime, condition = j$condition,
                 rep_id = j$rep_id, fit_variant = j$fit_variant, status = r$status,
                 logM_mean = mean(x), has_loo = !is.null(r$loo))
})
readr::write_csv(by_fit, file.path(out, "d_g4_by_fit.csv"))
loo_of <- setNames(lapply(recs, `[[`, "loo"), vapply(recs, function(r) as.numeric(r$job$job_id), numeric(1)))

# elpd(normal) - elpd(gumbel_min): > 0 favours Gaussian (v3 sign convention)
cmp_family <- function(id_n, id_g) {
  a <- loo_of[[as.character(id_n)]]; b <- loo_of[[as.character(id_g)]]
  if (is.null(a) || is.null(b)) return(c(diff = NA_real_, se = NA_real_))
  cmp <- loo::loo_compare(list(normal = a, gumbel = b))
  c(diff = cmp["normal", "elpd_diff"] - cmp["gumbel", "elpd_diff"], se = max(cmp[, "se_diff"]))
}

pairs <- by_fit |>
  select(dprime, condition, rep_id, fit_variant, job_id, status, logM_mean) |>
  tidyr::pivot_wider(names_from = fit_variant, values_from = c(job_id, status, logM_mean))
res <- t(mapply(cmp_family, pairs$job_id_normal, pairs$job_id_gumbel_min))
pairs <- pairs |>
  mutate(elpd_diff = res[, "diff"], se = res[, "se"],
         favors_gumbel_2se = elpd_diff < -g4$mimicry_rule$two_se * se,
         favors_normal_2se = elpd_diff >  g4$mimicry_rule$two_se * se,
         family_gap = logM_mean_normal - logM_mean_gumbel_min,
         both_ok = status_normal %in% c("pass", "fail") & status_gumbel_min %in% c("pass", "fail"))
readr::write_csv(pairs, file.path(out, "d_g4_by_dataset.csv"))

rates <- pairs |> filter(both_ok, !is.na(elpd_diff)) |>
  group_by(condition, dprime) |>
  summarise(n = n(), prop_gumbel_2se = mean(favors_gumbel_2se),
            prop_normal_2se = mean(favors_normal_2se),
            median_elpd_diff = median(elpd_diff),
            mean_family_gap = mean(family_gap), .groups = "drop")
rates_pooled <- pairs |> filter(both_ok, !is.na(elpd_diff)) |>
  group_by(condition) |>
  summarise(n = n(), prop_gumbel_2se = mean(favors_gumbel_2se),
            prop_normal_2se = mean(favors_normal_2se),
            median_elpd_diff = median(elpd_diff), .groups = "drop")
readr::write_csv(rates, file.path(out, "d_g4_rates_by_dprime.csv"))
readr::write_csv(rates_pooled, file.path(out, "d_g4_rates_pooled.csv"))

# UV-induced shift in the Gaussian fit's log_M, paired on (d', rep)
shift <- pairs |>
  select(dprime, rep_id, condition, logM_mean_normal) |>
  tidyr::pivot_wider(names_from = condition, values_from = logM_mean_normal) |>
  mutate(uv_shift = uv - ev) |>
  group_by(dprime) |>
  summarise(n = n(), mean_uv_shift = mean(uv_shift), mcse = sd(uv_shift) / sqrt(n()),
            .groups = "drop")
readr::write_csv(shift, file.path(out, "d_g4_uv_shift.csv"))

mr <- g4$mimicry_rule
p_uv <- rates_pooled$prop_gumbel_2se[rates_pooled$condition == "uv"]
p_ev <- rates_pooled$prop_gumbel_2se[rates_pooled$condition == "ev"]
verdict <- if (p_uv >= mr$uv_min_prop && p_ev <= mr$ev_max_prop) "UV mimics gumbel_min" else
           "no UV mimicry by the pre-specified rule"
writeLines(c(verdict, sprintf("uv prop favours gumbel (>2SE) = %.3f; ev = %.3f", p_uv, p_ev)),
           file.path(out, "d_g4_verdict.txt"))
print(as.data.frame(rates), digits = 3); print(as.data.frame(shift), digits = 3)
cat("\nG4 verdict:", verdict, "\n")
```

### 4.6 Interpretation (pre-specified)

| G4 result | Interpretation of the empirical results |
|---|---|
| **UV mimics Gumbel-min** | When the empirical data favour Gumbel-min, this can only be written as "the evidence distributions are **asymmetric or have unequal variances**", **not** as "Gumbel-min is a particularly good fit" |
| **UV does not mimic** | When the empirical data favour Gumbel-min, you can write "the preference is not caused by this degree of unequal variance", but you must still state that only one variance ratio was tested |
| The EV control condition itself often favours Gumbel-min (> 10%) | This means the generator (with added metacognitive noise) itself departs from both models; report it as is, and explain it in the limitations |

### 4.7 Check for understanding

1. Why does G4 have no "true log M"? Why is the EV control condition enough to answer the question we care about?
2. Why is the zROC slope exactly 1/σ when σ_meta = 0? Why is it not when σ_meta > 0?
3. If UV shifts the Gaussian fit's log M upwards, is this in the same direction as G2's Δ_mis? What would that imply?

### 4.8 Commit

```bash
git add code/01_simulate/simulate_g4_uv.R tests/test_simulate_g4_uv.R \
        code/04_ppc_and_comparison/v3b_g4_summary.R data/processed/v3b/d_* docs/analysis_log.md
git commit -m "v3b D: unequal-variance generator (G4) and pre-specified mimicry verdict (80 fits)"
```

---

## 5. Work package E: figures

The budget for main figures is at most 5 (see 7.5). The B + C results are candidates for main figures; D goes in the supplementary material. Reuse the theme and Okabe–Ito palette from `fig_6_relative_bias.R`.

### 5.1 `code/05_figures/fig_10_dprime_confound.R`

```r
# Fig. 10 (v3b): spurious log_M group differences when groups differ only in d'.
# A: false-positive rate by N x T, separate fits (work package B), correct vs Gaussian.
# B: posterior mean of the group difference, single two-group model (work package C).
suppressPackageStartupMessages({ library(dplyr); library(ggplot2); library(patchwork) })
okabe_v <- c(correct = "#009E73", misspecified = "#D55E00")
lab_v   <- c(correct = "Correct (Gumbel-min)", misspecified = "Gaussian (misspecified)")

b <- readr::read_csv(here::here("data", "processed", "v3b", "b_dprime_confound_by_cell.csv"),
                     show_col_types = FALSE) |> filter(analysis == "primary")
pA <- ggplot(b, aes(n_trials, fpr, colour = fit_variant, shape = factor(n_participants))) +
  geom_hline(yintercept = 0.05, linetype = 2, colour = "grey40") +
  geom_pointrange(aes(ymin = fpr_lo, ymax = fpr_hi), position = position_dodge(width = 0.2)) +
  scale_x_continuous(trans = "log2", breaks = c(100, 200, 400)) +
  scale_colour_manual(values = okabe_v, labels = lab_v) +
  coord_cartesian(ylim = c(0, 1)) +
  labs(subtitle = "A. Separate fits per group: 95% CrI of the difference excludes 0",
       x = "Trials per participant (log scale)", y = "False-positive rate (Wilson 95% CI)",
       colour = NULL, shape = "N per group") +
  theme_minimal() + theme(legend.position = "top")

c2 <- readr::read_csv(here::here("data", "processed", "v3b", "c_two_group_by_fit.csv"),
                      show_col_types = FALSE) |> filter(status %in% c("pass", "fail"))
pB <- ggplot(c2, aes(fit_variant, diff_mean, colour = fit_variant)) +
  geom_hline(yintercept = 0, linetype = 2, colour = "grey40") +
  geom_pointrange(aes(ymin = diff_q025, ymax = diff_q975, alpha = excl0),
                  position = position_jitter(width = 0.25, seed = 1)) +
  scale_alpha_manual(values = c(`FALSE` = 0.35, `TRUE` = 1), name = "CrI excludes 0") +
  scale_colour_manual(values = okabe_v, labels = lab_v, guide = "none") +
  scale_x_discrete(labels = lab_v) +
  labs(subtitle = "B. One model with a group effect (N = 20 + 20, T = 200)",
       x = NULL, y = "log M (high d') - log M (low d'); truth = 0") +
  theme_minimal() + theme(legend.position = "top")

dir.create(here::here("outputs", "figures", "v3b"), recursive = TRUE, showWarnings = FALSE)
ggsave(here::here("outputs", "figures", "v3b", "fig_10_dprime_confound.png"),
       pA + pB + plot_layout(widths = c(1.4, 1)), width = 11, height = 4.5, dpi = 300)
```

### 5.2 `code/05_figures/fig_S_g4_uv.R`

```r
# Fig. S (v3b): G4 unequal-variance check. elpd(normal) - elpd(gumbel_min) per dataset,
# ev vs uv, by d'. Reference lines at 0; points coloured by > 2 SE preference.
suppressPackageStartupMessages({ library(dplyr); library(ggplot2) })
d <- readr::read_csv(here::here("data", "processed", "v3b", "d_g4_by_dataset.csv"),
                     show_col_types = FALSE) |> filter(both_ok) |>
  mutate(pref = case_when(favors_gumbel_2se ~ "Gumbel-min > 2 SE",
                          favors_normal_2se ~ "Gaussian > 2 SE", TRUE ~ "Inconclusive"))
p <- ggplot(d, aes(condition, elpd_diff, colour = pref)) +
  geom_hline(yintercept = 0, linetype = 2, colour = "grey40") +
  geom_pointrange(aes(ymin = elpd_diff - 2 * se, ymax = elpd_diff + 2 * se),
                  position = position_jitter(width = 0.2, seed = 1)) +
  facet_wrap(~ dprime, labeller = label_both) +
  scale_colour_manual(values = c("Gumbel-min > 2 SE" = "#D55E00", "Gaussian > 2 SE" = "#0072B2",
                                 "Inconclusive" = "grey60")) +
  scale_x_discrete(labels = c(ev = "Equal variance", uv = "Unequal (SD ratio 1.25)")) +
  labs(x = NULL, y = "elpd(Gaussian) - elpd(Gumbel-min)  (+/- 2 SE)", colour = NULL) +
  theme_minimal() + theme(legend.position = "top")
ggsave(here::here("outputs", "figures", "v3b", "fig_S_g4_uv.png"), p, width = 8, height = 4.5, dpi = 300)
```

```bash
Rscript code/05_figures/fig_10_dprime_confound.R
Rscript code/05_figures/fig_S_g4_uv.R
git add code/05_figures/fig_10_dprime_confound.R code/05_figures/fig_S_g4_uv.R outputs/figures/v3b
git commit -m "v3b figures: Fig. 10 (d' confound) and Fig. S (G4 unequal variance)"
```

### 5.3 Makefile and `run_v3.R`

Add the following at the end of the `Makefile`:

```make
.PHONY: v3b-reanalysis v3b-fits v3b-summary v3b-figures

v3b-reanalysis:
	$(RSCRIPT) code/03_recovery_analysis/v3b_dprime_confound_reanalysis.R

v3b-fits:     # 120 fits (40 two-group + 80 G4), single process
	$(RSCRIPT) code/00_setup/04_create_grid_v3b.R
	$(RSCRIPT) code/02_fit/run_v3b_jobs.R --shard 1 1

v3b-summary:
	$(RSCRIPT) code/04_ppc_and_comparison/v3b_two_group_summary.R
	$(RSCRIPT) code/04_ppc_and_comparison/v3b_g4_summary.R

v3b-figures:
	$(RSCRIPT) code/05_figures/fig_10_dprime_confound.R
	$(RSCRIPT) code/05_figures/fig_S_g4_uv.R
```

In `code/run_v3.R`, add `v3b_dprime_confound_reanalysis.R`, the two summary scripts and the two figure scripts to the list of steps that do not require refitting, in the same order as above.

---

## 6. Work package F: finishing the empirical analysis

The code for this part already exists (`docs/v3_plan.md` §5.8–5.10); only the order and checkpoints are listed here.

### 6.1 Steps after fitting is complete

```bash
# 1. Confirm that all 90 fits are present
Rscript -e 'length(list.files("data/interim/v3_empirical/fits", "[.]qs2$"))'   # 90
# 2. LOO repair (reloo or grouped K-fold, according to the pre-specified proportion)
Rscript code/06_empirical/05_loo_repair.R
# 3. PPC
Rscript code/06_empirical/06_ppc_dataset.R
# 4. Summary: main classification + pre-specified exploratory analyses + SD prior check
Rscript code/06_empirical/07_summarise_empirical.R
# 5. Figure 9
Rscript code/05_figures/fig_9_empirical.R
```

### 6.2 Checkpoints

| Check | Location | If it does not match |
|---|---|---|
| Both families in each dataset use the same LOO repair method | `method` in the output of `05_loo_repair.R` | Guaranteed by the code; if inconsistent, check `prop_bad` first |
| All four `exploratory_*.csv` files have been produced | `data/processed/v3/empirical/` | Confirm that `07_summarise_empirical.R` did not stop part-way |
| The `flag_sd_prior` column exists | `empirical_by_dataset.csv` | Follow `sd_prior_check` in `config/v3.yml` |
| Category proportions | `empirical_category_summary.csv` | **Report as is**; do not change the rules because of the results |

### 6.3 Interpreting the empirical results using v3b (pre-specified)

| Empirical result | G4 mimicry present | G4 mimicry absent |
|---|---|---|
| Majority favour Gumbel-min | "The evidence distributions are asymmetric or have unequal variances" | "The preference is not caused by this degree of unequal variance" |
| Majority favour Gaussian | "In these data the Gaussian assumption is broadly adequate" | Same as left |
| Majority inconclusive | "At typical data sizes the distributional assumption is hard to identify; but the simulations show that the bias still exists" | Same as left |

Add the B/C conclusions as well: if, among empirical datasets **with a condition difference**, the conclusion about the condition contrast flips between the two families (`conclusion_flip`), this is a real-data illustration of B/C; if there is no flip, report that as is too.

### 6.4 Commit

```bash
git add data/processed/v3/empirical outputs/figures/v3 docs/analysis_log.md
git commit -m "v3 empirical: LOO repair, PPC, pre-specified summary and exploratory tables; Fig. 9"
```

---

## 7. Work package G: writing

### 7.1 `docs/positioning.md` (half a day)

Three paragraphs, total length ≤ 1 page:

1. **What they did**:
   - Rausch, Hellmann & Zehetleitner (*Psychological Methods*): varied the confidence mechanism, with Gaussian signals throughout. **Check the volume, issue and DOI yourself.**
   - Meyer-Grant, Kellen, Harding & Singmann (*Psychological Review*): compared Gumbel-min and Gaussian on confidence ROCs in recognition memory; out-of-sample prediction mostly favoured Gumbel-min.
   - Rahnev (2025, *Nature Communications*): evaluated 17 measures using empirical data, all assuming the equal-variance Gaussian.
   - The `hmetad` alternative distributions vignette: demonstrates parameter recovery only under correct specification.
2. **What this study adds**: within the meta-d′ type-2 framework and hierarchical models, it quantifies the effect of distributional misspecification on log M (including bias that changes with d′ and the resulting spurious group differences), whether it can be detected, its relationship with unequal variance, and the empirical association in perceptual confidence data.
3. **What this study does not claim**: that meta-d′ is invalid; that it is the first to find that meta-d′ depends on assumptions; that Gumbel-min is the true distribution of human evidence; that log M measures σ_c.

Always replace "the first" with "to our knowledge".

### 7.2 Effect-size benchmarks (half a day, **at most 3 papers**)

Aim: to compare Δ_mis (about 0.1–0.25 log units) and the B/C group differences against the scale seen in real studies.

Method:
1. From literature you already know, pick 2–3 studies that report **between-group or between-condition differences in M-ratio (or log M-ratio)**. You could prioritise papers related to the Confidence Database, or studies using HMeta-d to analyse clinical populations.
2. For each paper, record: population or condition, group mean M-ratio, difference value, and whether it is on the log scale. Conversion: log M difference = log(M₁) − log(M₂).
3. Make a small table for the Discussion: "Δ_mis is approximately X% of the group differences reported in these studies".

**Rule**: use only numbers you have read yourself in the original papers. I have not looked up these values for you, so the document contains no numbers; do not copy them from secondary sources.

### 7.3 Discussion paragraph on unequal variance (including G4 results)

Structure (about 200 words):
1. The unequal-variance Gaussian is the most common violation in perception and memory research (zROC slope ≠ 1).
2. Gumbel-min also produces asymmetric ROCs, so the two may mimic each other.
3. G4 results: whether UV (SD ratio 1.25) makes LOO favour Gumbel-min, and the shift it causes in the Gaussian fit's log M (cite the numbers from `d_g4_*`).
4. Limitations: only one SD ratio tested; only one generator (SDT with added metacognitive noise).

### 7.4 Comparison with Meyer-Grant et al. (one paragraph)

Qualitative comparison only: is the direction of preference in your **memory** datasets (secondary analysis) consistent with their results? Do not compare dataset by dataset (already recorded in `deferred.md`).

### 7.5 Revising the paper

Keep the structure from Stage 4 of `docs/enhancement_plan_v2.md`, updated as follows:

**Order of main results**
1. Sanity checks (G0 calibration, brief; G1 moved to the supplementary material)
2. Consequences of misspecification: Δ_mis, change with d′, not disappearing with more data, coverage
3. **Spurious group differences** (B + C)
4. Detectability: LOO (after repair), PPC of the highest-confidence cells
5. Alternative explanations: G3 (difficulty mixture), G4 (unequal variance)
6. Empirical: category proportions, changes in log M and condition contrasts, SD prior check, exploratory diagnostic tables

**Main figures (at most 5)**

| # | Content | Source |
|---|---|---|
| 1 | Design overview (update `fig_1_design.R` to add G3, G4 and the two-group design) | — |
| 2 | Δ_mis and coverage | Figure 6 |
| 3 | Spurious group differences | Figure 10 |
| 4 | Detectability: LOO before and after repair + targeted PPC | Figure 7 + the v1.2 PPC figure |
| 5 | Empirical results | Figure 9 |

Supplementary material: G1, G3 (Figure 8), G4 (Figure S), v1 Figures 5–7, all exploratory tables.

**What Methods must state explicitly**
- Every pre-specified tag and commit (`v3-prereg-g3`, `v3-prereg-empirical`, `v3b-prereg`), and every deviation (sampling settings, 100-participant cap, SD prior), with the commit hash.
- The empirical LOO unit is aggregated counts per "participant × condition".
- Known limitations: one misspecification family plus one UV ratio, one true log M value, K = 4, `hmetad`/brms only.

**Writing rules**: "was associated with", "was consistent with"; every number must be traceable to a CSV in `data/processed/`; **write the abstract last**, starting from the numbers (five steps: question → design → consequences → detectability → empirical).

---

## 8. Work package H: pre-submission checklist and release

### 8.1 Essential submission items

- [ ] Data and code availability statement (GitHub + Zenodo DOI; raw data not included, with download instructions and `raw_manifest.csv`)
- [ ] Pre-specification statement: tags, commits, list of deviations, and a note that this is not a formal preregistration (no third-party timestamp)
- [ ] Confidence Database licence and citations: the database paper (Rahnev et al., 2020) + **the original paper for every dataset used**
- [ ] Ethics statement for secondary data (public, de-identified data; write according to journal requirements)
- [ ] CRediT author contributions, conflicts of interest, funding statement
- [ ] **AI use statement** (according to journal policy, stating which parts used AI assistance)
- [ ] `README.md`: v2.0 status, reproduction commands (`make v3b-*` etc.), new figures, data access
- [ ] Change `CITATION.cff` to 2.0.0; update `docs/deliverables_checklist.md`
- [ ] Journal formatting, word count and figure limits; cover letter; suggested reviewers (avoiding conflicts of interest)
- [ ] All tests pass: `Rscript -e 'testthat::test_dir("tests")'`
- [ ] From a clean clone, rerun the steps that do not require fitting (`code/run_downstream.R`, `code/run_v3.R`) and confirm the numbers match

### 8.2 Human readers (the easiest to skip, the most valuable)

- Find 1–2 readers: a supervisor, a lab colleague, or someone working on metacognition or computational modelling.
- Ask them to answer three questions:
  1. Is the contribution clear relative to Rausch et al. and Meyer-Grant et al.?
  2. Are there any places where claims go too far?
  3. Which result is most convincing? Which is weakest?
- Give them 1–2 weeks. Use their comments only for **rewriting**, not for adding new analyses (unless they point out a clear error).

### 8.3 Release and submission

```bash
git checkout main
git merge --no-ff v3-enhancement
git tag v2.0.0
git push origin main --tags
```

1. Obtain a DOI for v2.0.0 through the Zenodo–GitHub integration.
2. Upload to PsyArXiv, linking GitHub and the DOI.
3. Read the aims & scope and preprint policies of 2–3 candidate journals (suggested order: *Behavior Research Methods* → *Computational Brain & Behavior* → *Meta-Psychology* or *Neuroscience of Consciousness*), and choose one to submit to.
4. Only after submission, change the CV entry to "Preprint (under review)".

---

## Appendix A: troubleshooting common errors

| Symptom | Likely cause | Fix |
|---|---|---|
| `could not find function "gumbel_min_lcdf"` | `simulate_g2_gumbel.R` was not sourced | The first line of `run_v3b_jobs.R` already sources it; your own test scripts must source it too |
| `fit_one_hmetad: every covariate must also be listed in agg_by` | C's `agg_by` was not set to `"group"` | Check the `two` condition in `fit_job()` |
| `b_groupB` not found | The factor level name is different | Use the method in 3.6 to see the actual name, update the summary script and record it |
| `priors do not correspond to any model parameter` | `log_M_b_prior` is set but the formula has no log M covariate | Only two_group passes `log_M_covariates`; the default already handles this |
| A G4 job has status `error` and the message mentions `simulate_g4_uv.R not written yet` | Jobs from 41 onwards were run before D's simulator was written | Delete those `g4_*` error records and rerun (delete only those with `status == "error"`) |
| `confidence must be coded 1:K` | The number of G4 thresholds does not match K in `design.yml` | `conf_thresholds` must contain 3 values (K = 4) |
| zROC slope test fails | Too few trials or thresholds at extreme values | Use 200000 trials; confirm `sd_threshold_jitter = 0` and `sd_criterion = 0` |
| Empirical fits become noticeably slower after adding v3b shards | CPU contention | Normal; if necessary, pause the v3b loop first (Ctrl+C; completed jobs will not be rerun) |
| `pivot_wider` produces list columns | A key combination is duplicated | Use `count(..., fit_variant) |> filter(n > 1)` to find the duplicates and record them |

## Appendix B: summary of decision points

| Location | Condition | If met | If not met |
|---|---|---|---|
| 1.5 | `v3b-prereg` has been tagged and pushed | Start B | Complete it first |
| 2.3 | B's sanity checks match | Proceed to C | First check the pairing direction and file names |
| 3.6 | C's trial run has `b_groupB` | Run all 40 | Change the parameter name and record it |
| 3.8 | `framing_rule` holds in B or C | Main framing: "spurious group differences" | Main framing: "a common shift, with absolute values affected" (report both) |
| 4.3 | All G4 tests pass | Submit the 80 fits | You may only adjust `conf_thresholds`; record it, then commit |
| 4.6 | `mimicry_rule` holds | When the empirical data favour Gumbel, write "asymmetric or unequal variances" | Write "not caused by this degree of UV" |
| 6.2 | Empirical category proportions | **Report as is** | Do not change the rules because of the results |
| 8.2 | A human reader points out a clear error | Correct it | Use other comments only for rewriting |

## Appendix C: timeline

Counted in "working days", with computing running in the background; the empirical fits need roughly another 2–3 days.

| Day | Foreground work | Background computing |
|---|---|---|
| 1 | A (setup, tag) + B (reanalysis) | Empirical fits |
| 2 | C's code, tests, trial run → submit C | Empirical + C (2–5 h) |
| 3 | D's simulator, tests, trial run → submit D; C's summary | Empirical + D (4–10 h) |
| 4 | D's summary; Figure 10, Figure S; `positioning.md` | Empirical (should be nearly complete) |
| 5 | Effect-size benchmarks, UV discussion, Meyer-Grant paragraph | — |
| 6 | Finishing the empirical analysis (F) | LOO repair (reloo/K-fold, several hours) |
| 7–10 | Revising the paper (7.5 in G) | — |
| 11 | Submission checklist (8.1 in H) → send to human readers | — |
| Wait 1–2 weeks | — | — |
| 1–2 days afterwards | Revise according to comments → v2.0.0 → DOI → preprint → submit | — |

The **freeze point** is the end of day 6: after this, only writing; no new analyses are added.
