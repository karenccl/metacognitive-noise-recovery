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
