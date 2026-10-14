# v3b job table, work package C (two_group) only. Run once.
# Work package D (g4) is deferred (docs/deferred.md); when it is resumed, replace
# this with the full C + D version in docs/v3b_plan.md §3.4 and add the g4 section
# back to config/v3b.yml. Job ids 1-40 are unchanged by that.
cfgb <- yaml::read_yaml(here::here("config", "v3b.yml"))
b <- as.integer(cfgb$seed_base_v3b)
grid <- tidyr::expand_grid(rep_id = seq_len(cfgb$two_group$replications),
                           fit_variant = unlist(cfgb$two_group$fit_variants)) |>
  dplyr::mutate(study = "two_group", condition = "g2", dprime = NA_real_,
                sim_seed = b + 10000L + rep_id,          # same data for both variants
                job_id = dplyr::row_number(), fit_seed = sim_seed + 1000000L) |>
  dplyr::select(job_id, study, condition, dprime, rep_id, fit_variant, sim_seed, fit_seed)
stopifnot(nrow(grid) == 2 * cfgb$two_group$replications)   # 40
readr::write_csv(grid, here::here("config", "grid_v3b.csv"))
print(dplyr::count(grid, study, condition, fit_variant))
