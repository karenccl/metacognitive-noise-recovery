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
| References | `manuscript/references.bib` | Verified against Crossref 2026-09-28 (one page range unconfirmed) |
| Prior record | `outputs/tables/prior_summary.csv` | Done |
| Single-fit refit reproduces stored draws exactly | `data/interim/` | Done 2026-09-28 (grid cell 721; same machine and versions) |
| Fresh-clone check (figures only) | n/a | Done 2026-09-28: all five figures rebuild from a clean clone; full-pipeline reproduction (renv::restore + fits) not done |
| `make` targets run end to end | `Makefile` | Not run (`make` not installed); scripts run individually |
| PPC across all 480 G2 fits (v1.1) | `data/processed/v2/`, `outputs/figures/v2/fig_g2_ppc_all.png` | Done 2026-09-28; reverses the v1.0 PPC conclusion |
| Replicated-data PPC on 48 stored G2 fits (v1.2) | `data/processed/v2/g2_ppp_*.csv`, `outputs/figures/v2/fig_g2_ppp.png` | Done 2026-09-29; verdict Partial, stat 2 named |
| Release tag (v1.0.0; v1.0.1 report clarifications; v1.1.0 PPC correction; v1.2.0 practical PPC check) | n/a | v1.2.0 prepared 2026-09-29 |
| Archive (Zenodo/OSF) | n/a | Optional, not done |
