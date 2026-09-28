# G1 primary metrics (docs/design_decisions.md). G0's bias/RMSE/
# coverage are computed in compile_results.R -- this script is scoped
# to G1's ordinal-recovery estimands, the primary deliverable for RQ1:
#   - posterior mean log_M by replicate (primary point estimate, the same
#     one used for G0/G2 bias and RMSE; posterior median as a sensitivity)
#   - per-level means of log_M and pairwise level differences with Monte
#     Carlo SEs, per N x T x dprime_target condition. (Revised 2026-09-28:
#     an earlier version regressed log_M linearly on sigma_c and printed
#     p-values. The three calibrated levels are not equally spaced on any
#     natural scale and p-values on simulation replicates depend only on
#     the number of replications, so both were dropped.)
#   - Spearman correlation between sigma_c and posterior median log_M
#   - ordering accuracy (paired by rep_id -- NOTE: sigma_c levels do
#     NOT share simulation seeds in this grid, see the caveat below)
#   - pairwise "separation probability" between sigma_c levels
#     (Mann-Whitney-style, doesn't require seed-matching)
#   - convergence-failure and refit rates by condition
#   - empirical type-1 d' checks against the calibrated target
#   - confidence-category marginal proportions (see the cut-point
#     diagnostics caveat below)
#
# Computed on BOTH the primary analysis set (status pass+fail, flagged)
# and a pass-only sensitivity set, per the pre-specified failed-fit
# rule (docs/design_decisions.md).
#
# Run from the project root: Rscript code/03_recovery_analysis/compute_primary_metrics.R

suppressPackageStartupMessages(library(dplyr))

cfg <- yaml::read_yaml(here::here("config", "design.yml"))
compiled <- readr::read_csv(here::here("data", "processed", "compiled_results.csv"), show_col_types = FALSE)

g1_all <- compiled |> dplyr::filter(generator == "g1")
stopifnot(nrow(g1_all) == 36 * cfg$grid$replications$target)

sigma_c_map <- cfg$ddm$sigma_c_values  # named list: low/medium/high -> numeric value
g1_all$sigma_c_value <- unlist(sigma_c_map[g1_all$sigma_c_level])

# --- Convergence failure / refit rates (on the FULL attempted set --------
# these are computational-difficulty outcomes, not filtered by the
# failed-fit analysis rule, which only governs *parameter-estimate*
# inclusion; the design).

failure_rates <- g1_all |>
  dplyr::group_by(n_participants, n_trials, dprime_target, sigma_c_level) |>
  dplyr::summarise(
    n_attempted = dplyr::n(),
    n_pass = sum(status == "pass"),
    n_fail = sum(status == "fail"),
    n_error = sum(status == "error"),
    failure_rate = mean(status %in% c("fail", "error")),
    refit_rate = mean(escalated),
    .groups = "drop"
  )
readr::write_csv(failure_rates, here::here("data", "processed", "g1_failure_rates.csv"))

cat("=== G1 convergence failure / refit rates ===\n")
print(failure_rates, n = Inf)

# --- Empirical type-1 d' per replicate, from agg's N matrix ---------------
# Column layout (hmetad::aggregate_metad(), K=4): N_0_1..N_0_4 = (R=0,
# C=4..1), N_0_5..N_0_8 = (R=1, C=1..4) for stimulus=0; N_1_* likewise
# for stimulus=1. Hits = response=1 | stimulus=1; false alarms =
# response=1 | stimulus=0. Pooled across participants within a
# replicate (not saved in compiled_results.csv -- re-reads the interim
# files, since agg isn't carried into the compact summary table).

compute_empirical_dprime <- function(agg) {
  fa_count <- sum(agg$N[, 5:8])
  hit_count <- sum(agg$N[, 13:16])
  n0 <- sum(agg$N_0)
  n1 <- sum(agg$N_1)
  clamp <- function(p) pmin(pmax(p, 1 / (2 * max(n0, n1))), 1 - 1 / (2 * max(n0, n1)))
  hit_rate <- clamp(hit_count / n1)
  fa_rate <- clamp(fa_count / n0)
  tibble::tibble(
    hit_rate = hit_rate, fa_rate = fa_rate,
    empirical_dprime = stats::qnorm(hit_rate) - stats::qnorm(fa_rate)
  )
}

# Confidence-category marginal proportions (pooled across participants
# and both responses/stimuli): columns 1:4 and 9:12 are R=0 (C=4..1),
# columns 5:8 and 13:16 are R=1 (C=1..4) -- reorder to C=1..4 for both
# response types and sum.
compute_category_props <- function(agg) {
  cols <- agg$N
  c1 <- sum(cols[, 4]) + sum(cols[, 5]) + sum(cols[, 12]) + sum(cols[, 13])  # confidence=1
  c2 <- sum(cols[, 3]) + sum(cols[, 6]) + sum(cols[, 11]) + sum(cols[, 14])  # confidence=2
  c3 <- sum(cols[, 2]) + sum(cols[, 7]) + sum(cols[, 10]) + sum(cols[, 15])  # confidence=3
  c4 <- sum(cols[, 1]) + sum(cols[, 8]) + sum(cols[, 9]) + sum(cols[, 16])   # confidence=4
  total <- c1 + c2 + c3 + c4
  tibble::tibble(
    prop_conf_1 = c1 / total, prop_conf_2 = c2 / total,
    prop_conf_3 = c3 / total, prop_conf_4 = c4 / total
  )
}

g1_files <- list.files(here::here("data", "interim"), pattern = "^g1_.*\\.qs2$", full.names = TRUE)
cat("\nRe-reading", length(g1_files), "G1 interim files for empirical d'/category checks...\n")

g1_extra <- purrr::map_dfr(g1_files, function(f) {
  r <- qs2::qs_read(f)
  dplyr::bind_cols(
    tibble::tibble(grid_id = r$grid_id),
    compute_empirical_dprime(r$agg),
    compute_category_props(r$agg)
  )
})

g1_all <- dplyr::left_join(g1_all, g1_extra, by = "grid_id")

calibration <- readr::read_csv(here::here("outputs", "tables", "ddm_calibration.csv"), show_col_types = FALSE)

dprime_check <- g1_all |>
  dplyr::group_by(dprime_target) |>
  dplyr::summarise(
    n = dplyr::n(),
    mean_empirical_dprime = mean(empirical_dprime),
    sd_empirical_dprime = stats::sd(empirical_dprime),
    mean_prop_conf_1 = mean(prop_conf_1), mean_prop_conf_4 = mean(prop_conf_4),
    .groups = "drop"
  ) |>
  dplyr::left_join(
    dplyr::select(calibration, dprime_target, calibration_empirical_dprime = empirical_dprime_hit_fa),
    by = "dprime_target"
  )
readr::write_csv(dprime_check, here::here("data", "processed", "g1_empirical_dprime_check.csv"))

cat("\n=== G1 empirical d' vs. calibration target (pooled across N/T/sigma_c) ===\n")
print(dprime_check)
cat("\nNote: category-count marginals (prop_conf_1..4) are reported for descriptive\n")
cat("completeness; per the design, these are ~equal by construction under the\n")
cat("locked rank-based discretisation and are NOT a degeneracy diagnostic. Per-replicate\n")
cat("tie/cut-point diagnostics (discretise_confidence()'s own output) were not persisted\n")
cat("in the compact run_one_cell.R output format (a Day-2 storage tradeoff) and were\n")
cat("instead validated at representative settings during the Day-1 calibration pilot\n")
cat("(outputs/tables/sigma_c_pilot.csv) -- not re-audited per production replicate here.\n")

# --- Primary G1 estimands, by (N, T, dprime_target) condition -------------

compute_condition_metrics <- function(df, est = "log_M_mean") {
  df$estimate <- df[[est]]
  df |>
    dplyr::group_by(n_participants, n_trials, dprime_target) |>
    dplyr::group_modify(function(sub, key) {
      spearman <- stats::cor(sub$sigma_c_value, sub$estimate, method = "spearman")

      by_level <- split(sub$estimate, sub$sigma_c_level)
      low <- by_level[["low"]]; medium <- by_level[["medium"]]; high <- by_level[["high"]]

      # Ordering accuracy: paired by rep_id. Sigma_c levels do NOT share
      # simulation seeds in this grid (each (N,T,dprime,sigma_c,rep) cell
      # has its own independent sim_seed -- see code/00_setup/02_create_grid.R),
      # so this pairs by replicate INDEX only, not common random numbers;
      # a valid but higher-variance Monte Carlo comparison than CRN would give.
      ord <- dplyr::inner_join(
        sub |> dplyr::filter(sigma_c_level == "low") |> dplyr::select(rep_id, low = estimate),
        sub |> dplyr::filter(sigma_c_level == "medium") |> dplyr::select(rep_id, medium = estimate),
        by = "rep_id"
      ) |>
        dplyr::inner_join(
          sub |> dplyr::filter(sigma_c_level == "high") |> dplyr::select(rep_id, high = estimate),
          by = "rep_id"
        )
      ordering_accuracy <- mean(ord$low > ord$medium & ord$medium > ord$high)
      n_matched_reps <- nrow(ord)

      # Separation probability (Mann-Whitney-style probability of
      # superiority across ALL replicate pairs, not just matched
      # rep_ids -- doesn't require seed-matching, so uses the full
      # sample at each sigma_c level).
      sep_prob <- function(a, b) mean(outer(a, b, `>`))
      # Difference in level means; SE treats the levels as independent
      # samples (independent sim_seeds), so it is a Monte Carlo SE of the
      # mean difference, not an inferential test.
      mc_diff <- function(a, b) c(diff = mean(a) - mean(b), se = sqrt(stats::var(a) / length(a) + stats::var(b) / length(b)))
      d_lm <- mc_diff(low, medium); d_mh <- mc_diff(medium, high); d_lh <- mc_diff(low, high)

      tibble::tibble(
        n_reps_per_level = length(low),
        n_matched_reps = n_matched_reps,
        mean_low = mean(low), mean_medium = mean(medium), mean_high = mean(high),
        sd_low = stats::sd(low), sd_medium = stats::sd(medium), sd_high = stats::sd(high),
        mcse_low = stats::sd(low) / sqrt(length(low)),
        mcse_medium = stats::sd(medium) / sqrt(length(medium)),
        mcse_high = stats::sd(high) / sqrt(length(high)),
        diff_low_medium = d_lm[["diff"]], diff_low_medium_mcse = d_lm[["se"]],
        diff_medium_high = d_mh[["diff"]], diff_medium_high_mcse = d_mh[["se"]],
        diff_low_high = d_lh[["diff"]], diff_low_high_mcse = d_lh[["se"]],
        spearman_rho = spearman,
        ordering_accuracy = ordering_accuracy,
        sep_prob_low_gt_medium = sep_prob(low, medium),
        sep_prob_medium_gt_high = sep_prob(medium, high),
        sep_prob_low_gt_high = sep_prob(low, high)
      )
    }) |>
    dplyr::ungroup()
}

primary_set <- g1_all |> dplyr::filter(status %in% c("pass", "fail"))
sensitivity_set <- g1_all |> dplyr::filter(status == "pass")

cat("\n=== Primary analysis (status pass+fail, n =", nrow(primary_set), ") ===\n")
primary_metrics <- compute_condition_metrics(primary_set)
print(primary_metrics, n = Inf, width = Inf)
readr::write_csv(primary_metrics, here::here("data", "processed", "g1_primary_metrics.csv"))

cat("\n=== Sensitivity analysis (status pass-only, n =", nrow(sensitivity_set), ") ===\n")
sensitivity_metrics <- compute_condition_metrics(sensitivity_set)
print(sensitivity_metrics, n = Inf, width = Inf)
readr::write_csv(sensitivity_metrics, here::here("data", "processed", "g1_sensitivity_metrics.csv"))

cat("\n=== Point-estimate sensitivity: posterior MEDIAN instead of mean (pass+fail) ===
")
median_metrics <- compute_condition_metrics(primary_set, est = "log_M_median")
readr::write_csv(median_metrics, here::here("data", "processed", "g1_primary_metrics_median.csv"))
print(dplyr::select(median_metrics, n_participants, n_trials, dprime_target, spearman_rho, ordering_accuracy), n = Inf)

cat("\n=== Direction check: low > medium > high in the level means ===
")
chk <- function(m) sum(m$diff_low_medium > 0 & m$diff_medium_high > 0)
cat("Primary (mean):", chk(primary_metrics), "/ 12; pass-only:", chk(sensitivity_metrics), "/ 12; median:", chk(median_metrics), "/ 12\n")
cat("Smallest adjacent difference in MC SEs (mean):",
    round(min(c(primary_metrics$diff_low_medium / primary_metrics$diff_low_medium_mcse,
                primary_metrics$diff_medium_high / primary_metrics$diff_medium_high_mcse)), 1), "\n")
cat("Ordering accuracy range (mean / median):",
    sprintf("%.2f-%.2f / %.2f-%.2f", min(primary_metrics$ordering_accuracy), max(primary_metrics$ordering_accuracy),
            min(median_metrics$ordering_accuracy), max(median_metrics$ordering_accuracy)), "\n")

cat("\nDone. Wrote data/processed/g1_failure_rates.csv, g1_empirical_dprime_check.csv,\n")
cat("g1_primary_metrics.csv, g1_sensitivity_metrics.csv, g1_primary_metrics_median.csv.\n")
