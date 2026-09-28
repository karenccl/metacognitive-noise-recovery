# G2 correct-vs-Gaussian LOO/ELPD comparison (protocol sections 3.3,
# 6.3). Pairs the two fit variants by (cell_id, rep_id) -- they were
# fit to the IDENTICAL simulated dataset (code/00_setup/02_create_grid.R
# gives both variants of a G2 cell the same sim_seed), so
# loo::loo_compare() is a valid same-data comparison.
#
# LOO observation unit (verified 2026-09-23/24, see docs/design_decisions.md
# and docs/analysis_log.md): brms::log_lik() on these hierarchical
# aggregated-count models returns a `draws x n_participants` matrix --
# one LOO observation is one PARTICIPANT's aggregated response/confidence
# count vector, not one trial. All ELPD/Pareto-k interpretation below is
# at that unit; no trial-level generalisation is implied (protocol
# section 4, understanding check 5).
#
# Run from the project root: Rscript code/04_ppc_and_comparison/loo_comparison.R

suppressPackageStartupMessages(library(dplyr))

compiled <- readr::read_csv(here::here("data", "processed", "compiled_results.csv"), show_col_types = FALSE)
g2_meta <- compiled |> dplyr::filter(generator == "g2")

g2_files <- list.files(here::here("data", "interim"), pattern = "^g2_.*\\.qs2$", full.names = TRUE)
cat("Reading", length(g2_files), "G2 interim files...\n")

g2_loaded <- purrr::map(g2_files, function(f) {
  r <- qs2::qs_read(f)
  list(
    cell_id = r$cell_id, rep_id = r$rep_id, fit_variant = r$fit_variant,
    n_participants = r$n_participants, n_trials = r$n_trials,
    dprime_target = r$dprime_target, status = r$status, loo = r$loo
  )
})

by_key <- split(g2_loaded, sapply(g2_loaded, function(x) paste(x$cell_id, x$rep_id)))

# --- Pareto k summary, pooled by fit variant --------------------------------

pareto_summary <- purrr::map_dfr(g2_loaded, function(x) {
  if (is.null(x$loo)) {
    return(tibble::tibble(
      fit_variant = x$fit_variant, n_participants = x$n_participants,
      n_trials = x$n_trials, dprime_target = x$dprime_target,
      max_k = NA_real_, n_k_bad = NA_integer_, n_obs = NA_integer_
    ))
  }
  k <- x$loo$diagnostics$pareto_k
  tibble::tibble(
    fit_variant = x$fit_variant, n_participants = x$n_participants,
    n_trials = x$n_trials, dprime_target = x$dprime_target,
    max_k = max(k), n_k_bad = sum(k > 0.7), n_obs = length(k)
  )
})

pareto_by_variant <- pareto_summary |>
  dplyr::filter(!is.na(max_k)) |>
  dplyr::group_by(fit_variant) |>
  dplyr::summarise(
    n_fits = dplyr::n(),
    n_total_obs = sum(n_obs),
    n_obs_k_bad = sum(n_k_bad),
    prop_obs_k_bad = sum(n_k_bad) / sum(n_obs),
    mean_max_k = mean(max_k),
    n_fits_with_any_bad_k = sum(n_k_bad > 0),
    .groups = "drop"
  )

cat("\n=== Pareto k summary by fit variant (k > 0.7 = unreliable) ===\n")
print(pareto_by_variant)
readr::write_csv(pareto_summary, here::here("data", "processed", "g2_pareto_k_by_fit.csv"))
readr::write_csv(pareto_by_variant, here::here("data", "processed", "g2_pareto_k_summary.csv"))

# --- Paired ELPD comparison --------------------------------------------------

compare_pair <- function(pair_list) {
  variants <- sapply(pair_list, function(x) x$fit_variant)
  if (!all(c("correct", "misspecified") %in% variants)) return(NULL)
  correct <- pair_list[[which(variants == "correct")]]
  mis <- pair_list[[which(variants == "misspecified")]]
  if (is.null(correct$loo) || is.null(mis$loo)) return(NULL)

  cmp <- tryCatch(
    loo::loo_compare(list(correct = correct$loo, misspecified = mis$loo)),
    error = function(e) NULL
  )
  if (is.null(cmp)) return(NULL)

  elpd_diff_correct_minus_mis <- cmp["correct", "elpd_diff"] - cmp["misspecified", "elpd_diff"]
  se_diff <- cmp[which.max(abs(cmp[, "elpd_diff"])), "se_diff"]
  if (length(se_diff) == 0 || is.na(se_diff)) se_diff <- 0

  tibble::tibble(
    cell_id = correct$cell_id, rep_id = correct$rep_id,
    n_participants = correct$n_participants, n_trials = correct$n_trials,
    dprime_target = correct$dprime_target,
    status_correct = correct$status, status_misspecified = mis$status,
    elpd_diff_correct_minus_mis = elpd_diff_correct_minus_mis,
    se_diff = se_diff,
    favors_correct = elpd_diff_correct_minus_mis > 0,
    favors_correct_2se = elpd_diff_correct_minus_mis > 2 * se_diff
  )
}

cat("\nComparing", length(by_key), "paired G2 datasets...\n")
elpd_comparisons <- purrr::map_dfr(by_key, compare_pair)

readr::write_csv(elpd_comparisons, here::here("data", "processed", "g2_elpd_comparison.csv"))
cat("Wrote data/processed/g2_elpd_comparison.csv (", nrow(elpd_comparisons), "pairs )\n")

elpd_summary <- elpd_comparisons |>
  dplyr::group_by(n_participants, n_trials, dprime_target) |>
  dplyr::summarise(
    n_pairs = dplyr::n(),
    mean_elpd_diff = mean(elpd_diff_correct_minus_mis),
    sd_elpd_diff = stats::sd(elpd_diff_correct_minus_mis),
    prop_favors_correct = mean(favors_correct),
    prop_favors_correct_2se = mean(favors_correct_2se),
    .groups = "drop"
  )
readr::write_csv(elpd_summary, here::here("data", "processed", "g2_elpd_summary.csv"))

cat("\n=== ELPD comparison summary by condition (positive = correct model preferred) ===\n")
print(elpd_summary, n = Inf)

overall_prop <- mean(elpd_comparisons$favors_correct)
overall_prop_2se <- mean(elpd_comparisons$favors_correct_2se)
cat(sprintf(
  "\nOverall: correct model favored in %.1f%% of %d pairs (%.1f%% at >2SE)\n",
  overall_prop * 100, nrow(elpd_comparisons), overall_prop_2se * 100
))

# --- log_M recovery: correct vs. misspecified (known truth = -1) -----------
# Primary G2 estimand (protocol section 3.3): recovery of the generating
# model's own log_M. Both variants target the SAME nominal scale here
# (both are the hmetad "M-ratio on log scale" dpar), but this is a
# within-hmetad comparison, not a claim that any two arbitrary
# distributions' log_M are on an identical substantive scale more
# generally (protocol's scale caveat).

log_M_ground_truth <- yaml::read_yaml(here::here("config", "design.yml"))$truth$log_M

g2_recovery <- g2_meta |>
  dplyr::filter(status %in% c("pass", "fail")) |>
  dplyr::mutate(error = log_M_mean - log_M_ground_truth) |>
  dplyr::group_by(n_participants, n_trials, dprime_target, fit_variant) |>
  dplyr::summarise(
    n_reps = dplyr::n(),
    bias = mean(error),
    rmse = sqrt(mean(error^2)),
    mean_ci_width = mean(log_M_q975 - log_M_q025),
    .groups = "drop"
  )
readr::write_csv(g2_recovery, here::here("data", "processed", "g2_log_M_recovery.csv"))

cat("\n=== G2 log_M recovery: correct vs. misspecified (known truth = -1) ===\n")
print(g2_recovery, n = Inf)

cat("\nDone. Wrote g2_pareto_k_by_fit.csv, g2_pareto_k_summary.csv,\n")
cat("g2_elpd_comparison.csv, g2_elpd_summary.csv, g2_log_M_recovery.csv.\n")
