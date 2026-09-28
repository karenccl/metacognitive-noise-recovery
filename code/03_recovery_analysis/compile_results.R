# Compile all per-cell results from data/interim/ into compact
# processed products in data/processed/. Verifies each intended
# condition/replicate is represented exactly once and surfaces
# failures from structured status fields, not missing files alone
# (docs/design_decisions.md; Day 3 morning).
#
# Outputs:
#   data/processed/compiled_results.csv  -- one row per grid row, with
#     grid metadata, status/diagnostics, and a log_M posterior point
#     summary (mean/median/sd/95% CI) extracted from the compact
#     draws_b_sd saved by run_one_cell.R. This is the table every
#     downstream analysis script (compute_primary_metrics.R,
#     prior_sensitivity.R, ppc scripts) should read instead of
#     re-reading all data/interim/*.qs2 files.
#   data/processed/g0_recovery_summary.csv -- per-condition G0 bias/
#     RMSE/coverage/interval-width, per the pre-specified failed-fit
#     rule (primary = pass+fail, flagged; see docs/design_decisions.md).
#
# Run from the project root: Rscript code/03_recovery_analysis/compile_results.R

suppressPackageStartupMessages(library(dplyr))

`%||%` <- function(x, y) if (is.null(x)) y else x

cfg <- yaml::read_yaml(here::here("config", "design.yml"))
grid <- readr::read_csv(here::here("config", "grid.csv"), show_col_types = FALSE)

# Locked constant duplicated from code/02_fit/run_one_cell.R (not stored
# per-row in the saved results since it never varies across the grid).
# TODO: centralise into config/design.yml so the two can't drift.
log_M_ground_truth <- yaml::read_yaml(here::here("config", "design.yml"))$truth$log_M

interim_dir <- here::here("data", "interim")
interim_files <- list.files(interim_dir, pattern = "\\.qs2$", full.names = TRUE)

cat("Grid rows (intended):", nrow(grid), "| interim files found:", length(interim_files), "\n")

# --- Read every result and extract a compact summary row -------------------

extract_log_M_summary <- function(draws_b_sd) {
  if (is.null(draws_b_sd) || !"b_Intercept" %in% names(draws_b_sd)) {
    return(tibble::tibble(
      log_M_mean = NA_real_, log_M_median = NA_real_, log_M_sd = NA_real_,
      log_M_q025 = NA_real_, log_M_q975 = NA_real_
    ))
  }
  x <- draws_b_sd$b_Intercept
  tibble::tibble(
    log_M_mean = mean(x), log_M_median = stats::median(x), log_M_sd = stats::sd(x),
    log_M_q025 = stats::quantile(x, 0.025, names = FALSE),
    log_M_q975 = stats::quantile(x, 0.975, names = FALSE)
  )
}

compile_one <- function(path) {
  r <- qs2::qs_read(path)
  diag <- r$diagnostics

  tibble::tibble(
    grid_id = r$grid_id, cell_id = r$cell_id, generator = r$generator,
    fit_variant = r$fit_variant, n_participants = r$n_participants,
    n_trials = r$n_trials, dprime_target = r$dprime_target,
    sigma_c_level = r$sigma_c_level, rep_id = r$rep_id,
    status = r$status, escalated = isTRUE(r$escalated),
    elapsed_secs = r$elapsed_secs %||% NA_real_,
    error_message = r$error_message %||% NA_character_,
    max_rhat = if (!is.null(diag)) diag$max_rhat else NA_real_,
    min_ess_bulk = if (!is.null(diag)) diag$min_ess_bulk else NA_real_,
    min_ess_tail = if (!is.null(diag)) diag$min_ess_tail else NA_real_,
    n_divergent = if (!is.null(diag)) diag$n_divergent else NA_integer_,
    n_at_max_treedepth = if (!is.null(diag)) diag$n_at_max_treedepth else NA_integer_
  ) |>
    dplyr::bind_cols(extract_log_M_summary(r$draws_b_sd))
}

compiled <- purrr::map_dfr(interim_files, compile_one)

# --- Completeness check: every intended grid row exactly once --------------

grid_ids_intended <- sort(grid$grid_id)
grid_ids_found <- sort(compiled$grid_id)

missing_ids <- setdiff(grid_ids_intended, grid_ids_found)
duplicate_ids <- grid_ids_found[duplicated(grid_ids_found)]
unexpected_ids <- setdiff(grid_ids_found, grid_ids_intended)

cat("\n=== Completeness check ===\n")
cat("Missing grid_ids (intended but no file):", length(missing_ids), "\n")
if (length(missing_ids) > 0) print(missing_ids)
cat("Duplicate grid_ids (file appears more than once):", length(duplicate_ids), "\n")
if (length(duplicate_ids) > 0) print(duplicate_ids)
cat("Unexpected grid_ids (file for a row not in grid.csv):", length(unexpected_ids), "\n")
if (length(unexpected_ids) > 0) print(unexpected_ids)

if (length(missing_ids) == 0 && length(duplicate_ids) == 0 && length(unexpected_ids) == 0) {
  cat("OK: every intended grid row is represented exactly once.\n")
}

# --- Status summary (from structured status fields, not file presence) -----

cat("\n=== Status summary ===\n")
print(dplyr::count(compiled, generator, status))

dir.create(here::here("data", "processed"), showWarnings = FALSE, recursive = TRUE)
readr::write_csv(compiled, here::here("data", "processed", "compiled_results.csv"))
cat("\nWrote data/processed/compiled_results.csv (", nrow(compiled), "rows )\n")

# --- G0 recovery metrics: bias, RMSE, coverage, interval width -------------
# Primary analysis per the pre-specified rule (docs/design_decisions.md):
# include pass + fail (flagged), exclude error (no posterior to include).

g0 <- compiled |>
  dplyr::filter(generator == "g0", status %in% c("pass", "fail")) |>
  dplyr::mutate(
    error = log_M_mean - log_M_ground_truth,
    sq_error = error^2,
    covered = log_M_q025 <= log_M_ground_truth & log_M_ground_truth <= log_M_q975,
    ci_width = log_M_q975 - log_M_q025
  )

g0_summary <- g0 |>
  dplyr::group_by(n_participants, n_trials, dprime_target) |>
  dplyr::summarise(
    n_reps = dplyr::n(),
    n_pass = sum(status == "pass"),
    n_fail = sum(status == "fail"),
    bias = mean(error),
    rmse = sqrt(mean(sq_error)),
    n_covered = sum(covered),
    coverage = mean(covered),
    mean_ci_width = mean(ci_width),
    .groups = "drop"
  )

# Wilson score interval for coverage (Monte Carlo binomial uncertainty on
# the coverage proportion itself -- the design).
g0_summary <- g0_summary |>
  dplyr::rowwise() |>
  dplyr::mutate(
    coverage_ci = list(stats::prop.test(n_covered, n_reps, correct = FALSE)$conf.int),
    coverage_ci_low = coverage_ci[1],
    coverage_ci_high = coverage_ci[2]
  ) |>
  dplyr::ungroup() |>
  dplyr::select(-coverage_ci)

readr::write_csv(g0_summary, here::here("data", "processed", "g0_recovery_summary.csv"))

cat("\n=== G0 recovery summary (by condition) ===\n")
print(g0_summary, n = Inf)

# Pooled coverage across all G0 cells (the design's own resolution for
# per-cell coverage being imprecise at any feasible replication count --
# docs/design_decisions.md's Day-2 reps-30->20 rationale).
pooled_n <- sum(g0$covered, na.rm = TRUE)
pooled_total <- nrow(g0)
pooled_ci <- stats::prop.test(pooled_n, pooled_total, correct = FALSE)$conf.int
cat("\n=== Pooled G0 coverage across all cells ===\n")
cat(sprintf(
  "%d / %d = %.3f (95%% CI [%.3f, %.3f]), MCSE = %.4f\n",
  pooled_n, pooled_total, pooled_n / pooled_total, pooled_ci[1], pooled_ci[2],
  sqrt((pooled_n / pooled_total) * (1 - pooled_n / pooled_total) / pooled_total)
))

pooled_summary <- tibble::tibble(
  n_reps = pooled_total, n_covered = pooled_n, coverage = pooled_n / pooled_total,
  coverage_ci_low = pooled_ci[1], coverage_ci_high = pooled_ci[2],
  mcse = sqrt((pooled_n / pooled_total) * (1 - pooled_n / pooled_total) / pooled_total)
)
readr::write_csv(pooled_summary, here::here("data", "processed", "g0_pooled_coverage.csv"))

cat("\nWrote data/processed/g0_recovery_summary.csv and g0_pooled_coverage.csv\n")
cat("Done.\n")
