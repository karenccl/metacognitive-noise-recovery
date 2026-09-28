# Deliverables checklist

Status as of 2026-09-28. "Done" means produced and committed; it does not mean externally reviewed.

| Deliverable | Location | Status |
|---|---|---|
| Design lock and dated deviations | `docs/design_decisions.md` | Done |
| Analysis log (incl. corrections) | `docs/analysis_log.md` | Done |
| Environment record | `docs/computational_environment.md`, `renv.lock` | Done (backend: rstan) |
| Config and grid | `config/design.yml`, `config/grid.csv` | Done |
| Generators, fit wrapper, tests | `code/01_simulate/`, `code/02_fit/`, `tests/` | Done (54 tests pass) |
| Production fits (1,440) | `data/interim/` (git-ignored) | Done; 1,437 pass, 3 fail |
| Compact results tables | `data/processed/` | Done |
| Five headline figures | `outputs/figures/` | Done |
| Report | `manuscript/report.md` | Draft |
| Supplementary methods | `manuscript/supplementary_methods.md` | Draft |
| References | `manuscript/references.bib` | **Unverified** (entered from memory) |
| Prior record | `outputs/tables/prior_summary.csv` | Done |
| Fresh-clone check (figures only) | n/a | Done 2026-09-28: all five figures rebuild from a clean clone; full-pipeline reproduction (renv::restore + fits) not done |
| `make` targets run end to end | `Makefile` | Not run (`make` not installed); scripts run individually |
| Release tag (v1.0.0) | n/a | Not done, awaiting the project owner |
| Archive (Zenodo/OSF) | n/a | Optional, not done |
| Protocol document | n/a | Not in the repository |
