# Does a static meta-d′ model track dynamic confidence? A simulation study of `hmetad` under post-decisional noise and distributional misspecification

*Draft for author review. All numbers are taken from `data/processed/*.csv` (1,440 fits). Reference details in `references.bib` should be checked against the sources before release.*

## Abstract

**Background.** Static meta-d′ models are widely fitted to confidence ratings, although confidence may arise from dynamic, noisy post-decisional processes. **Methods.** We simulated ordinal confidence from a drift-diffusion process with post-decisional readout noise (G1), from the meta-d′ model itself (G0), and from a non-Gaussian Gumbel-min signal distribution (G2), and fitted hierarchical Bayesian meta-d′ models with `hmetad` (20 or 40 participants, 100–400 trials, 20 replications per cell; 1,440 fits). **Results.** In G1, posterior log M fell as readout noise rose in all 12 design cells (slopes −0.50 to −0.63); the expected ordering held in every matched replication in 11 cells and in 95% in the twelfth. G0 credible-interval coverage was 95.8% pooled across cells. In G2, leave-one-out comparison preferred the correct family in 96.2% of datasets, and Gaussian misspecification biased log M upward (+0.06 to +0.20). Posterior predictive discrepancies were small for every representative fit, including the misspecified one. **Conclusions.** In this generator, ordinal recovery of metacognitive efficiency was robust, but small predictive discrepancy did not diagnose misspecification. Conclusions are conditional on the simulated processes.

## 1. Background and rationale

Metacognitive efficiency is commonly estimated as the M-ratio, meta-d′/d′, from a signal detection model of confidence ratings (Maniscalco & Lau, 2012), with hierarchical Bayesian estimation available through HMeta-d (Fleming, 2017) and, in R, through `brms`-based implementations (Bürkner, 2017). These models are *static*: confidence is a fixed function of a single-trial latent variable. Dynamic accounts instead let evidence keep accumulating after a choice, so that confidence reflects post-decisional information (Pleskac & Busemeyer, 2010). If confidence is generated dynamically and read out noisily, it is not obvious that a static model's M-ratio should still order individuals or conditions sensibly.

Simulation is required because real data contain no known noise parameter, so recovery cannot be assessed on them. We therefore ask what a particular estimator does under explicitly stated generating processes (Morris et al., 2019). The study cannot show that human confidence arises from the simulated mechanism, and it does not estimate any literal neural "metacognitive noise".

## 2. Research questions and preregistered-style predictions

Design decisions were written to `docs/design_decisions.md` before production runs and any deviation is dated there and in `docs/analysis_log.md`.

- **RQ1 (G1).** When confidence is generated with readout noise σ_c, does posterior `log_M` from a static Gaussian model fall monotonically as σ_c rises? *Prediction:* negative slope of `log_M` on σ_c and the ordering low > medium > high in most replications. We do not claim that `log_M` numerically recovers σ_c; the two are on different scales.
- **RQ2 (G2).** When the signal distribution is Gumbel-min, how do inference and predictive fit change between the correctly specified and the default Gaussian model? *Prediction:* LOO prefers the correct family, more strongly with more data.
- **RQ3.** How often do fits fail diagnostics, and where? Failure is reported as an outcome, not as bias.

## 3. Methods

### 3.1 Software and reproducibility
R 4.5.0, `hmetad` 0.2.1, `brms` 2.23.0, sampled with `brms`'s default `rstan` backend (rstan 2.36.0.9000, the Stan 2.36 series; confirmed from the saved fits). CmdStan 2.36.0 was installed and smoke-tested but did not run any model. All package versions are locked in `renv.lock`; see `docs/computational_environment.md`. Every simulation and fit has a deterministic seed derived from a base seed and a stable grid index (`config/grid.csv`, `config/design.yml`).

### 3.2 Data-generating processes
**Design grid.** N ∈ {20, 40} participants × T ∈ {100, 200, 400} trials × target first-order d′ ∈ {0.75, 1.5}; G1 adds three σ_c levels; 20 replications per cell. Confidence has K = 4 categories.

**G0.** Data drawn from the equal-variance Gaussian meta-d′ model with known `log_M` = −1 and no between-participant variability in d′, criterion or M (240 fits).

**G1.** Per trial, a diffusion process starts at a/2 with drift ±v, is simulated by Euler–Maruyama (dt = 1 ms, diffusion coefficient 1) until it crosses 0 or a, and then *continues* unbounded for a fixed post-decision duration τ = 0.3 s. The confidence-relevant quantity q is the post-decisional evidence relative to the starting point, sign-flipped so that positive values favour the chosen response. Readout noise is added, y = q + ε with ε ~ N(0, σ_c²), and y is converted to four confidence categories by a rank-based within-participant quartile rule. The continuous q and y are retained. Confidence is never derived from reaction time. Drift v was calibrated by bisection so that empirical d′ matched 0.75 and 1.5 (v = 0.388 and 0.797 at a = 1.5, t0 = 0.3 s); the realized pooled d′ across the production grid was 0.743 and 1.50. The three σ_c values (0.291, 0.872, 2.91) were chosen from a pilot sweep so that the confidence–accuracy association was clearly and non-arbitrarily separated (Spearman 0.287, 0.176, 0.062) (720 fits).

**G2.** Same structure as G0 but with a Gumbel-min signal distribution, fixed to unit variance and mean-centred so that its location parameter plays the role of the Gaussian mean (480 fits: each simulated dataset was fitted twice).

### 3.3 Fitted models and priors
All fits use a hierarchical `hmetad` model with participant-level random intercepts on `log_M`, d′ and criterion, pooled confidence-threshold gaps, absolute type-2 criterion, a `normal(0, 1)` prior on population `log_M` and `normal(0, 1)` on the threshold gaps, K = 4, and an aggregated multinomial likelihood. Sampling: 4 chains × (1,000 warm-up + 1,000 draws), adapt_delta 0.95, max treedepth 12. G2 was fitted under the correct `gumbel_min` family (with matching Stan-side CDF functions) and under the default Gaussian family.

### 3.4 Diagnostics, refit and failure policy
A fit passes if max R-hat < 1.01, bulk and tail ESS ≥ 400, and there are no divergences or maximum-treedepth hits, judged on population-level effects and random-effect SDs. A flagged fit is refitted once (adapt_delta 0.99, treedepth 14). If it is still flagged it is labelled `fail`. **Pre-registered rule:** the primary analysis includes `pass` and `fail` fits (failures flagged); the sensitivity analysis uses `pass` only; `error` rows would be excluded from estimation and counted as convergence failures.

### 3.5 Metrics
G0: bias, RMSE, 95% credible-interval coverage (Wilson intervals; pooled across cells because per-cell coverage is imprecise at 20 replications). G1: per-cell regression slope of posterior median `log_M` on σ_c, Spearman correlation, ordering accuracy (paired by replication index; σ_c levels do not share simulation seeds), and Mann–Whitney-style separation probabilities. G2: paired ELPD difference (correct − misspecified) from LOO, whose observation unit is one *participant's* aggregated count vector, and `log_M` bias/RMSE for each family. Robustness: prior width, K = 6 binning, and posterior predictive checks.

## 4. Results

### 4.1 G0: recovery when the model is correct (Fig. 2)
Posterior mean `log_M` was negatively biased in all 12 cells (−0.177 to −0.025), and RMSE generally fell with more data and higher d′ (from 0.326 at N = 20, T = 200, d′ = 0.75 to 0.069 at N = 40, T = 400, d′ = 1.5), though not strictly monotonically in T within d′ = 0.75. Pooled coverage was 95.8% (230/240; 95% CI 92.5–97.7%; MCSE 1.3%). Per-cell coverage ranged from 80% to 100%, which is uninformative on its own at 20 replications per cell.

### 4.2 G1: ordinal recovery (Fig. 3)
All 720 G1 fits passed. In all 12 N × T × d′ cells the slope of `log_M` on σ_c was negative (−0.504 to −0.627; every p < 10⁻²¹), Spearman ρ was between −0.92 and −0.94, and separation probabilities for adjacent noise levels were ≥ 0.965. Ordering accuracy was 100% (20/20 matched replications) in 11 cells and 95% (19/20) in the remaining one. Pass-only sensitivity results are identical because there were no failures. The K = 6 binning check (5 replications per level, 20 fits) gave the same ordering accuracy (100% at K = 4 and K = 6).

### 4.3 G2: distributional misspecification (Fig. 4)
The correct family was preferred in 96.2% of the 240 paired datasets (72.9% by more than two standard errors). The mean ELPD advantage grew from +2.2 at N = 20, T = 100, d′ = 0.75 to +83.1 at N = 40, T = 400, d′ = 1.5; in the least informative cells the preference was weak (as few as 10% of pairs exceeded two SE). The correctly specified fit had a small negative `log_M` bias in all 12 cells (−0.092 to −0.007; RMSE 0.042–0.272). The Gaussian fit was biased *upward* in all 12 cells (+0.064 to +0.195; RMSE 0.105–0.299), i.e. it made participants look more metacognitively efficient than the generating truth. **Pareto-k caveat:** 12.0% (correct) and 8.2% (misspecified) of LOO observations had k > 0.7, affecting most fits (181/240 and 165/240 had at least one such participant). No remedy was applied, so ELPD magnitudes are approximate; the direction is supported by its consistency across pairs.

### 4.4 Model adequacy (Fig. 5)
For five representative fits (N = 40, T = 200, d′ = 1.5, replication 1: G0, G1 low noise, G1 high noise, G2 correct, G2 misspecified) the RMSE of observed minus predicted cell proportions was 0.0024–0.0072, small for all. The misspecified fit had the largest discrepancy, and in this replicate its four largest cell errors were all at the highest confidence category. This rests on one replicate per fit and is suggestive only. G1 had no failed fit to display.

### 4.5 Convergence and failure (RQ3)
Across 1,440 fits: 1,437 pass, 3 fail (G0 N = 40/T = 400/d′ = 0.75; two G2-correct fits at T = 100, d′ = 0.75, both divergence-driven), 0 errors; no fit reached maximum treedepth. Escalation was more patterned than failure: 7.5–12.5% by generator, up to 55% in low-d′, short-T, high-σ_c cells. Diagnostics describe each row's final attempt only.

### 4.6 Sensitivity to the prior (single replicate)
Refitting one G0 and one G1 dataset under `normal(0, 0.5)`, `normal(0, 1)` and `normal(0, 2)` shifted the posterior mean monotonically toward zero as the prior tightened (G0: −0.939, −0.958, −0.966; G1: −0.722, −0.733, −0.736), a modest range relative to posterior SDs of about 0.07–0.09. This argues against prior shrinkage toward zero as the *cause* of the negative bias in 4.1 and 4.3, because shrinkage toward zero would push a true −1 toward less negative values; but one replicate per generator cannot resolve a bias of this size, and the source of the small negative bias is not established here.

## 5. Discussion

**What the results support.** Under this generator, a static Gaussian meta-d′ model fitted hierarchically ordered conditions by readout noise reliably, across the full range of sample sizes tried. This supports using `log_M` as an *ordinal* index of confidence quality in designs like these. It does not show that `log_M` measures σ_c: only ordering was tested, and the two are on different scales.

**Parameter trend versus model adequacy.** Ordinal agreement and small predictive discrepancy both coexisted with genuine misspecification in G2. There, LOO separated the models clearly and increasingly with data, whereas aggregate posterior predictive discrepancy was small even for the wrong model. Point estimates were also systematically distorted (upward bias under the Gaussian fit). So a reasonable-looking `log_M` trend and small aggregate PPC error should not be read as evidence that the fitted static model is a generatively adequate account of the confidence distribution.

**Implications.** Analysts who fit static meta-d′ models to data plausibly generated by noisy post-decisional accumulation can expect the *ordering* of efficiency across conditions to be preserved, but should check distributional fit (for example by comparing alternative signal distributions with LOO) before interpreting the absolute level of M.

**Limitations.** (i) The RQ1 test is comparatively favourable: adding independent noise to the readout of one evidence stream removes information in a way any monotone confidence model should register; other dynamic mechanisms (e.g. confidence depending on decision time, or separate evidence streams) were not simulated. (ii) σ_c levels were calibrated at d′ = 1.5 and reused at d′ = 0.75. (iii) `log_M` truth was fixed at −1 in G0/G2, one confidence-threshold structure was used, and G0/G2 have no between-participant variability in d′, criterion or M (thresholds vary slightly between simulated participants but were pooled in the fitted model). (iv) A small negative `log_M` bias (12/12 cells in both G0 and G2-correct) is unexplained. (v) LOO has unreliable Pareto-k values for a substantial share of observations and no remedy was applied. (vi) The K = 6 (n = 5 per level), prior (n = 1 per generator) and PPC (n = 1 per fit) checks are small; in the K = 6 check G0 point estimates moved by up to 0.38 (mean 0.21), although all K = 4/K = 6 credible intervals overlapped, so sensitivity to bin count for point estimates is not resolved. (vii) Per-replicate tie/cut-point diagnostics of the discretisation were not persisted in the compact output format. (viii) σ_c levels do not share seeds, so ordering accuracy is an independent-replicate comparison. (ix) No cross-check against JAGS HMeta-d and no open-data illustration were done. (x) Cross-distribution `log_M` comparisons are within `hmetad`'s parameterisation and do not claim identical substantive scale.

**Next steps.** Summarise PPC patterns across all 480 G2 fits; test alternative dynamic confidence mechanisms; apply a Pareto-k remedy; cross-check with HMeta-d.

## 6. Reproducibility statement

Code, configuration, seeds, compact per-fit results (`data/processed/`), figures and a dated decision/analysis log are in this repository. Full posterior objects are not stored except for replications 1–2 per cell (`data/interim/`, git-ignored). Run order: `make all` (setup, grid, G1, G0, G2, compile, analyse, figures), plus `make robustness` for the two refit-based checks (prior sweep and K = 6; roughly 20 and 75 minutes). The full grid took about 26 hours on one 22-core machine (see README). Deviations from the original protocol are listed in `docs/design_decisions.md`: `qs2` replaced the archived `qs`; explicit aggregation before fitting; replications reduced from 30 to 20 after measured throughput (~55 fits/hour); compact result records instead of full fit objects; chain-parallel sampling. Two latent bugs were found and fixed during the project (K-generic simulation; a hardcoded interpretation string), and one misattributed number was corrected in the log.

## 7. References

See `references.bib`. Cited: Maniscalco & Lau (2012); Fleming (2017); Pleskac & Busemeyer (2010); Bürkner (2017); Morris et al. (2019); Vehtari et al. (2017) for LOO/Pareto-k.
