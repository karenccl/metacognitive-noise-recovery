# v3 G3 grid (docs/v3_plan.md §4.4): condition x replication x fit variant.
# sim_seed depends only on (condition, rep_id), so all four fit variants of a
# replication are fitted to the identical simulated dataset.
#
# Run from the project root: Rscript code/00_setup/03_create_grid_g3.R

cfg_v3 <- yaml::read_yaml(here::here("config", "v3.yml"))
cfg3   <- cfg_v3$g3
seed0  <- cfg_v3$seed_base_v3

grid <- tidyr::expand_grid(
  condition   = names(cfg3$conditions),
  rep_id      = seq_len(cfg3$replications),
  fit_variant = cfg3$fit_variants
) |>
  dplyr::mutate(
    cond_idx = match(condition, names(cfg3$conditions)),
    sim_seed = seed0 + cond_idx * 1000L + rep_id,         # identical across fit variants
    fit_seed = sim_seed + 1000000L,
    g3_id    = dplyr::row_number()
  ) |>
  dplyr::select(g3_id, condition, rep_id, fit_variant, sim_seed, fit_seed)

stopifnot(nrow(grid) == length(cfg3$conditions) * cfg3$replications * length(cfg3$fit_variants))
readr::write_csv(grid, here::here("config", "grid_g3.csv"))
cat("Wrote config/grid_g3.csv (", nrow(grid), "rows )\n")
