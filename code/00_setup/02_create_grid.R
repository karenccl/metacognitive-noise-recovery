# Build config/grid.csv: one row per (generator x design-cell x
# fit_variant x replication), with a stable grid_id, derived from
# config/design.yml. Run after the replication count is locked
# (docs/design_decisions.md's Day 2 compute-benchmark decision).
#
# Cell structure:
#   - G0, G2: n_participants x n_trials x dprime_target (no sigma_c).
#   - G1: n_participants x n_trials x dprime_target x sigma_c_level.
#   - G2 additionally has TWO fit rows per generated dataset
#     (fit_variant "correct" [gumbel_min] and "misspecified" [gaussian]),
#     protocol section 3.3 ("G2 requires two fits per generated dataset").
#     Both rows share the same `cell_id`/`sim_seed` (same underlying
#     data) but distinct `grid_id`/`fit_seed` (independent Stan RNG).
#
# Seed derivation (protocol section 1.3's random-number policy): every
# sim_seed/fit_seed is deterministic, derived only from seed_base plus a
# stable integer index over the sorted cell/grid structure -- no reliance
# on hashing or wall-clock state.

suppressPackageStartupMessages(library(dplyr))

cfg <- yaml::read_yaml(here::here("config", "design.yml"))

n_participants_vec <- unlist(cfg$grid$n_subjects)
n_trials_vec <- unlist(cfg$grid$n_trials)
dprime_targets <- unlist(cfg$grid$dprime_target)
sigma_c_levels <- names(cfg$ddm$sigma_c_values)
n_reps <- cfg$grid$replications$target

g0_g2_cells <- tidyr::expand_grid(
  n_participants = n_participants_vec,
  n_trials = n_trials_vec,
  dprime_target = dprime_targets,
  sigma_c_level = NA_character_
)

g1_cells <- tidyr::expand_grid(
  n_participants = n_participants_vec,
  n_trials = n_trials_vec,
  dprime_target = dprime_targets,
  sigma_c_level = sigma_c_levels
)

# Run order (2026-09-23, user-directed): G1, then G0, then G2. Encoded
# here (not in run_grid.R) so it falls out of grid.csv's row order --
# run_grid.R just processes pending rows in file order.
generator_run_order <- c("g1", "g0", "g2")

cells <- dplyr::bind_rows(
  dplyr::mutate(g0_g2_cells, generator = "g0", .before = 1),
  dplyr::mutate(g1_cells, generator = "g1", .before = 1),
  dplyr::mutate(g0_g2_cells, generator = "g2", .before = 1)
) |>
  tidyr::expand_grid(rep_id = seq_len(n_reps)) |>
  dplyr::arrange(
    factor(generator, levels = generator_run_order),
    n_participants, n_trials, dprime_target, sigma_c_level, rep_id
  ) |>
  dplyr::mutate(cell_id = dplyr::row_number())

grid <- cells |>
  dplyr::mutate(fit_variant = purrr::map(generator, function(g) {
    if (g == "g2") c("correct", "misspecified") else "default"
  })) |>
  tidyr::unnest(fit_variant) |>
  dplyr::arrange(cell_id, fit_variant) |>
  dplyr::mutate(
    grid_id = dplyr::row_number(),
    sim_seed = cfg$seed_base + cell_id,
    fit_seed = cfg$seed_base + 1000000L + grid_id
  ) |>
  dplyr::select(
    grid_id, cell_id, generator, fit_variant,
    n_participants, n_trials, dprime_target, sigma_c_level, rep_id,
    sim_seed, fit_seed
  )

readr::write_csv(grid, here::here("config", "grid.csv"))

cat("Wrote", nrow(grid), "grid rows (", dplyr::n_distinct(grid$cell_id), "unique cells ) to config/grid.csv\n")
print(dplyr::count(grid, generator, fit_variant))
