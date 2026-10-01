# Summary of v3_sdprior_validation.R: the empirical configuration vs the stored
# v1 fits on identical simulated datasets (same grid_id / sim_seed).
#
# Run from the project root: Rscript code/03_recovery_analysis/v3_sdprior_validation_summary.R

suppressPackageStartupMessages(library(dplyr))
truth <- yaml::read_yaml(here::here("config", "design.yml"))$truth$log_M
out <- here::here("data", "processed", "v3")

val <- purrr::map_dfr(list.files(here::here("data", "interim", "v3_sdprior_val"), "[.]qs2$", full.names = TRUE),
  function(f) { r <- qs2::qs_read(f)
    tibble::tibble(grid_id = r$grid_id, status_v3 = r$status, log_M_v3 = r$log_M_mean,
                   q025_v3 = r$log_M_q025, q975_v3 = r$log_M_q975,
                   max_rhat_v3 = if (is.null(r$diagnostics)) NA_real_ else r$diagnostics$max_rhat,
                   n_div_v3 = if (is.null(r$diagnostics)) NA_real_ else r$diagnostics$n_divergent) })
v1 <- readr::read_csv(here::here("data", "processed", "compiled_results.csv"), show_col_types = FALSE) |>
  select(grid_id, generator, fit_variant, dprime_target, rep_id, status_v1 = status,
         log_M_v1 = log_M_mean, q025_v1 = log_M_q025, q975_v1 = log_M_q975)
by_fit <- inner_join(v1, val, by = "grid_id") |>
  mutate(fit = if_else(generator == "g0", "g0", paste0("g2_", fit_variant)),
         err_v1 = log_M_v1 - truth, err_v3 = log_M_v3 - truth,
         cov_v1 = q025_v1 <= truth & truth <= q975_v1, cov_v3 = q025_v3 <= truth & truth <= q975_v3,
         width_v1 = q975_v1 - q025_v1, width_v3 = q975_v3 - q025_v3,
         change = log_M_v3 - log_M_v1)
readr::write_csv(by_fit, file.path(out, "sdprior_validation_by_fit.csv"))

summ <- by_fit |> group_by(fit, dprime_target) |>
  summarise(n = n(), n_pass_v1 = sum(status_v1 == "pass"), n_pass_v3 = sum(status_v3 == "pass"),
            bias_v1 = mean(err_v1), bias_v3 = mean(err_v3, na.rm = TRUE),
            mean_change = mean(change, na.rm = TRUE), sd_change = sd(change, na.rm = TRUE),
            cover_v1 = mean(cov_v1), cover_v3 = mean(cov_v3, na.rm = TRUE),
            width_v1 = mean(width_v1), width_v3 = mean(width_v3, na.rm = TRUE), .groups = "drop")

# Misspecification shift (Gaussian - correct) on the same G2 dataset, v1 vs v3.
dmis <- by_fit |> filter(generator == "g2") |>
  select(dprime_target, rep_id, fit_variant, log_M_v1, log_M_v3) |>
  tidyr::pivot_wider(names_from = fit_variant, values_from = c(log_M_v1, log_M_v3)) |>
  mutate(delta_v1 = log_M_v1_misspecified - log_M_v1_correct,
         delta_v3 = log_M_v3_misspecified - log_M_v3_correct) |>
  group_by(dprime_target) |>
  summarise(n = n(), delta_mis_v1 = mean(delta_v1), delta_mis_v3 = mean(delta_v3, na.rm = TRUE),
            .groups = "drop")

readr::write_csv(summ, file.path(out, "sdprior_validation_summary.csv"))
readr::write_csv(dmis, file.path(out, "sdprior_validation_delta_mis.csv"))
print(as.data.frame(summ), digits = 3)
print(as.data.frame(dmis), digits = 3)
