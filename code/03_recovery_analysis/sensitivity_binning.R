# Confidence-binning sensitivity analysis: K=4 (production) vs K=6, on a
# small representative subset (N=40, T=200, d'=1.5; 20 of 1,440 fits).
#
# WHAT IS AND IS NOT A RE-BINNING (corrected 2026-09-28; an earlier
# version of this script and the report claimed both halves were):
#   * G1 IS a valid re-binning. simulate_g1_ddm() generates continuous
#     evidence y first and bins it afterwards, so K=4 and K=6 with the
#     same sim_seed share y and the same responses; only the number of
#     bins changes. (Checked: identical y and identical responses.)
#   * G0 is NOT. simulate_g0() draws discrete confidence directly from
#     hmetad's generative model, so K=6 is a different generative model
#     and a different random stream. With the same seed it shares only
#     the stimulus sequence (in the checked cell, responses agree on
#     95.1% of trials and the K=6 x K=4 confidence table is not
#     block-structured). Differences between the G0 K=4 and K=6 fits
#     therefore confound binning with a different dataset. They are
#     reported for completeness and support no inference about binning.
#
# The valid evidence is therefore G1: (a) paired change in posterior
# median log_M and whether credible intervals overlap, (b) whether the
# low > medium > high ordering (the RQ1 result) survives K=6.
#
# Fits are expensive (~75 min). By default this script REUSES the saved
# comparison (data/processed/sensitivity_binning_comparison.csv) and only
# rebuilds the tables; pass --refit to redo the 20 fits.
#
# Run from the project root:
#   Rscript code/03_recovery_analysis/sensitivity_binning.R [--refit]

suppressPackageStartupMessages(library(dplyr))

source(here::here("code", "01_simulate", "discretise_confidence.R"))
source(here::here("code", "01_simulate", "simulate_g1_ddm.R"))
source(here::here("code", "01_simulate", "simulate_g0.R"))
source(here::here("code", "02_fit", "extract_fit_summary.R"))
source(here::here("code", "02_fit", "fit_hmetad.R"))

cfg <- yaml::read_yaml(here::here("config", "design.yml"))
grid <- readr::read_csv(here::here("config", "grid.csv"), show_col_types = FALSE)
compiled <- readr::read_csv(here::here("data", "processed", "compiled_results.csv"), show_col_types = FALSE)
log_M_ground_truth <- -1
K_SENSITIVITY <- 6
N_REPS <- 5
comparison_path <- here::here("data", "processed", "sensitivity_binning_comparison.csv")
REFIT <- "--refit" %in% commandArgs(trailingOnly = TRUE) || !file.exists(comparison_path)

g0_rows <- grid |>
  dplyr::filter(generator == "g0", n_participants == 40, n_trials == 200,
                dprime_target == 1.5, rep_id <= N_REPS)
g1_rows <- grid |>
  dplyr::filter(generator == "g1", n_participants == 40, n_trials == 200,
                dprime_target == 1.5, rep_id <= N_REPS)
stopifnot(nrow(g0_rows) == N_REPS, nrow(g1_rows) == N_REPS * 3)

refit_k6 <- function(row) {
  if (row$generator == "g0") {
    data <- simulate_g0(
      n_participants = row$n_participants, n_trials = row$n_trials,
      dprime_target = row$dprime_target, log_M = log_M_ground_truth,
      k = K_SENSITIVITY, seed = row$sim_seed
    )
  } else {
    v <- cfg$ddm$v_by_dprime_target[[as.character(row$dprime_target)]]
    sigma_c <- cfg$ddm$sigma_c_values[[row$sigma_c_level]]
    data <- simulate_g1_ddm(
      n_participants = row$n_participants, n_trials = row$n_trials,
      v = v, a = cfg$ddm$a, t0 = cfg$ddm$t0, tau = cfg$ddm$tau,
      sigma_c = sigma_c, s = cfg$ddm$s, dt = cfg$ddm$dt,
      k = K_SENSITIVITY, seed = row$sim_seed
    )
  }

  fit_one_hmetad(
    data, K = K_SENSITIVITY, group = "participant",
    hierarchical_dprime_c = cfg$fitting$hierarchical_dprime_c,
    hierarchical_thresholds = cfg$fitting$hierarchical_thresholds,
    log_M_prior = cfg$priors$log_M_production, metac2_prior = cfg$priors$metac2_gap,
    chains = cfg$sampling$chains, cores = cfg$sampling$chains,
    warmup = cfg$sampling$warmup, iter_sampling = cfg$sampling$iter_sampling,
    adapt_delta = cfg$sampling$adapt_delta, max_treedepth = cfg$sampling$max_treedepth,
    rhat_max = cfg$diagnostics$rhat_max, bulk_ess_min = cfg$diagnostics$bulk_ess_min,
    tail_ess_min = cfg$diagnostics$tail_ess_min,
    seed = row$fit_seed,
    metadata = as.list(row)
  )
}

if (REFIT) {
  all_rows <- dplyr::bind_rows(g0_rows, g1_rows)
  k6_results <- vector("list", nrow(all_rows))
  for (i in seq_len(nrow(all_rows))) {
    row <- all_rows[i, ]
    cat(sprintf("[%d/%d] Fitting %s grid_id=%d at K=%d...\n", i, nrow(all_rows), row$generator, row$grid_id, K_SENSITIVITY))
    k6_results[[i]] <- refit_k6(row)
  }

  k6_summary <- purrr::map_dfr(k6_results, function(f) {
    draws <- posterior::as_draws_df(f$fit)$b_Intercept
    tibble::tibble(
      grid_id = f$grid_id, generator = f$generator, n_participants = f$n_participants,
      n_trials = f$n_trials, dprime_target = f$dprime_target, sigma_c_level = f$sigma_c_level,
      rep_id = f$rep_id, status_k6 = f$status,
      log_M_mean_k6 = mean(draws), log_M_median_k6 = stats::median(draws),
      log_M_q025_k6 = stats::quantile(draws, 0.025, names = FALSE),
      log_M_q975_k6 = stats::quantile(draws, 0.975, names = FALSE)
    )
  })

  k4_matched <- compiled |>
    dplyr::filter(grid_id %in% k6_summary$grid_id) |>
    dplyr::select(grid_id, status_k4 = status, log_M_mean_k4 = log_M_mean,
                  log_M_median_k4 = log_M_median, log_M_q025_k4 = log_M_q025,
                  log_M_q975_k4 = log_M_q975)

  comparison <- dplyr::left_join(k6_summary, k4_matched, by = "grid_id") |>
    dplyr::mutate(
      diff_median = log_M_median_k6 - log_M_median_k4,
      both_overlap_ci = pmax(log_M_q025_k4, log_M_q025_k6) <= pmin(log_M_q975_k4, log_M_q975_k6)
    )
  readr::write_csv(comparison, comparison_path)
} else {
  cat("Reusing saved comparison (pass --refit to redo the 20 fits).\n")
  comparison <- readr::read_csv(comparison_path, show_col_types = FALSE)
}

# Only G1 is a valid re-binning (see header).
comparison <- comparison |> dplyr::mutate(valid_rebinning = generator == "g1")
readr::write_csv(comparison, comparison_path)

# --- G0: how different are the K=4 and K=6 *datasets* for one cell? --------
g0_a <- simulate_g0(g0_rows$n_participants[1], g0_rows$n_trials[1], g0_rows$dprime_target[1],
                    log_M_ground_truth, k = 4, seed = g0_rows$sim_seed[1])
g0_b <- simulate_g0(g0_rows$n_participants[1], g0_rows$n_trials[1], g0_rows$dprime_target[1],
                    log_M_ground_truth, k = K_SENSITIVITY, seed = g0_rows$sim_seed[1])
g0_response_agreement <- mean(g0_a$response == g0_b$response)
cat(sprintf("\nG0 same-seed K=4 vs K=6: stimulus identical = %s; response agreement = %.3f\n",
            identical(g0_a$stimulus, g0_b$stimulus), g0_response_agreement))

g1c <- comparison |> dplyr::filter(generator == "g1")
g0c <- comparison |> dplyr::filter(generator == "g0")

ordering_of <- function(df, col) {
  w <- df |> dplyr::select(rep_id, sigma_c_level, value = dplyr::all_of(col)) |>
    tidyr::pivot_wider(names_from = sigma_c_level, values_from = value)
  list(acc = mean(w$low > w$medium & w$medium > w$high), n = nrow(w))
}
ord4 <- ordering_of(g1c, "log_M_median_k4")
ord6 <- ordering_of(g1c, "log_M_median_k6")

cat("\n=== G1 (valid re-binning): K=4 vs K=6 ===\n")
print(g1c |> dplyr::select(sigma_c_level, rep_id, log_M_median_k4, log_M_median_k6, diff_median, both_overlap_ci), n = Inf)
cat(sprintf("\nG1 ordering accuracy: K=4 %.0f%% (%d/%d), K=6 %.0f%% (%d/%d)\n",
            ord4$acc * 100, round(ord4$acc * ord4$n), ord4$n, ord6$acc * 100, round(ord6$acc * ord6$n), ord6$n))

robustness_table <- tibble::tibble(
  check = c("G1 re-binning: point estimates", "G1 re-binning: ordering (RQ1)", "G0 K=4 vs K=6 (NOT a re-binning)"),
  valid_binning_test = c(TRUE, TRUE, FALSE),
  data_subset = c(
    sprintf("G1, N=40/T=200/d'=1.5, 3 sigma_c levels x %d reps (n=%d)", N_REPS, nrow(g1c)),
    sprintf("G1, N=40/T=200/d'=1.5, %d matched replications", ord4$n),
    sprintf("G0, N=40/T=200/d'=1.5, %d reps; different simulated data (response agreement %.3f in the checked cell)", nrow(g0c), g0_response_agreement)
  ),
  estimand = c(
    "paired change in posterior median log_M (K=6 minus K=4)",
    "share of replications with log_M(low) > log_M(medium) > log_M(high)",
    "change in posterior median log_M between two different datasets"
  ),
  result = c(
    sprintf("mean |diff| = %.3f, max |diff| = %.3f, %d/%d CIs overlap", mean(abs(g1c$diff_median)), max(abs(g1c$diff_median)), sum(g1c$both_overlap_ci), nrow(g1c)),
    sprintf("K=4: %.0f%%; K=6: %.0f%%", ord4$acc * 100, ord6$acc * 100),
    sprintf("mean |diff| = %.3f, max |diff| = %.3f, %d/%d CIs overlap", mean(abs(g0c$diff_median)), max(abs(g0c$diff_median)), sum(g0c$both_overlap_ci), nrow(g0c))
  ),
  interpretation = c(
    sprintf("G1 estimates barely move with bin count: mean |diff| %.3f against K=4 interval half-widths of about %.2f-%.2f; %s.",
            mean(abs(g1c$diff_median)),
            min((g1c$log_M_q975_k4 - g1c$log_M_q025_k4) / 2), max((g1c$log_M_q975_k4 - g1c$log_M_q025_k4) / 2),
            if (all(g1c$both_overlap_ci)) "all intervals overlap" else "not all intervals overlap"),
    if (ord4$acc == ord6$acc) "The RQ1 ordering result does not depend on the K=4 choice." else "The ordering result changed between K=4 and K=6.",
    "Confounds binning with a different dataset and generative model; supports no conclusion about binning. Differences here reflect between-dataset variability."
  )
)

readr::write_csv(robustness_table, here::here("data", "processed", "robustness_table.csv"))
cat("\n=== Robustness table ===\n")
for (i in seq_len(nrow(robustness_table))) {
  cat("\n[", i, "]\n", sep = "")
  for (col in names(robustness_table)) cat(sprintf("  %-18s %s\n", col, robustness_table[[col]][i]))
}
cat("\nDone. Wrote sensitivity_binning_comparison.csv and robustness_table.csv\n")
