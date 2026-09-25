# Aggregate diagnostic/failure summary across G0/G1/G2 (protocol sections
# 4.4, 6.4): status counts, escalation (refit) rate, R-hat, ESS,
# divergences, treedepth hits, by generator/variant and by design cell.
#
# CAVEAT (stated in the outputs too): every diagnostic column and
# elapsed_secs in compiled_results.csv describes each row's FINAL attempt
# only. For the rows that were escalated (adapt_delta 0.99, treedepth 14)
# the first attempt's diagnostics/time are not retained, so the
# divergence/R-hat numbers below describe the fit that was kept, and
# elapsed_secs understates total compute for escalated rows.
#
# A "fail" here means the escalated retry still tripped a diagnostic flag
# (R-hat >= 1.01, ESS < 400, divergences or max-treedepth hits); a
# "fail" fit still has a posterior and stays in the primary analysis,
# flagged, per the pre-registered rule in docs/design_decisions.md.
#
# Run from the project root: Rscript code/04_ppc_and_comparison/diagnostics_summary.R

suppressPackageStartupMessages(library(dplyr))

compiled <- readr::read_csv(here::here("data", "processed", "compiled_results.csv"), show_col_types = FALSE)

summarise_diag <- function(df) {
  dplyr::summarise(
    df,
    n_fits = dplyr::n(),
    n_pass = sum(status == "pass"),
    n_fail = sum(status == "fail"),
    n_error = sum(status == "error"),
    failure_rate = mean(status %in% c("fail", "error")),
    escalation_rate = mean(escalated),
    median_max_rhat = stats::median(max_rhat, na.rm = TRUE),
    worst_max_rhat = max(max_rhat, na.rm = TRUE),
    median_min_ess_bulk = stats::median(min_ess_bulk, na.rm = TRUE),
    worst_min_ess_bulk = min(min_ess_bulk, na.rm = TRUE),
    worst_min_ess_tail = min(min_ess_tail, na.rm = TRUE),
    n_fits_with_divergences = sum(n_divergent > 0, na.rm = TRUE),
    total_divergences = sum(n_divergent, na.rm = TRUE),
    n_fits_at_max_treedepth = sum(n_at_max_treedepth > 0, na.rm = TRUE),
    median_elapsed_secs_final_attempt = stats::median(elapsed_secs, na.rm = TRUE),
    max_elapsed_secs_final_attempt = max(elapsed_secs, na.rm = TRUE),
    .groups = "drop"
  )
}

overall <- compiled |>
  dplyr::group_by(generator, fit_variant) |>
  summarise_diag()

by_cell <- compiled |>
  dplyr::group_by(generator, fit_variant, n_participants, n_trials, dprime_target, sigma_c_level) |>
  summarise_diag()

readr::write_csv(overall, here::here("data", "processed", "diagnostics_overall.csv"))
readr::write_csv(by_cell, here::here("data", "processed", "diagnostics_by_cell.csv"))

cat("=== Diagnostics by generator / fit variant (final attempt per row) ===\n")
print(as.data.frame(overall), row.names = FALSE, digits = 4)

cat("\n=== Cells containing any non-pass fit ===\n")
print(as.data.frame(dplyr::filter(by_cell, n_fail + n_error > 0) |>
  dplyr::select(generator, fit_variant, n_participants, n_trials, dprime_target, n_fits, n_fail, n_error)),
  row.names = FALSE)

cat("\n=== Cells with the highest escalation rates (top 8) ===\n")
print(as.data.frame(by_cell |> dplyr::arrange(dplyr::desc(escalation_rate)) |> head(8) |>
  dplyr::select(generator, fit_variant, n_participants, n_trials, dprime_target, sigma_c_level, n_fits, escalation_rate)),
  row.names = FALSE)

cat("\nWrote data/processed/diagnostics_overall.csv and diagnostics_by_cell.csv\nDone.\n")
