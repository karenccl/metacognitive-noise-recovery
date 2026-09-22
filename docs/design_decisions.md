# Design Decisions

Locked decisions per the project protocol (`docs/../publication_ready_hmetad_project_protocol.md`
supplied by the user). Record any justified deviation below with a date; do not silently alter
the core scientific question.

## Status

- [ ] Absolute vs. relative type-2 criteria decision, and why
- [ ] Aggregation route / expected `hmetad` input schema
- [ ] Exact primary/secondary outcomes
- [ ] Grid, seed scheme, sampling configuration, diagnostic/refit policy
- [ ] Definition of what counts as a deviation

## 2026-09-22 — Initial scaffold

Repository structure created per protocol section 2.1. No scientific decisions locked yet.

## 2026-09-23 — Deviation: qs → qs2

Protocol section 4.1 lists `qs` for atomic per-cell result storage. `qs` is archived on CRAN
and unavailable for R 4.5.0; installed `qs2` (same author, maintained successor) instead.
Interim result files now use `qs2::qs_save()`/`qs2::qs_read()` and the `.qs2` extension in
place of `.qs`. Purely a serialization-format substitution; no effect on the scientific design,
grid, or estimands. See `docs/computational_environment.md` and `docs/analysis_log.md` for
details.

## Locked decisions (from protocol)

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

## What this project must not claim

See protocol section 1.2. In particular: do not claim `log_M` "recovers" σ_c numerically; do not
report 95% CI coverage for σ_c using `log_M` intervals; do not call the G1 DDM process
"non-Gaussian" without separately establishing the empirical distributional feature tested; do
not treat a successful MCMC fit as evidence of generative correctness without PPCs; do not make
trial-level LOO claims when the likelihood is fit to aggregated subject-level cell counts.
