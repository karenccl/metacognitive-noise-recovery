# v2 extension 1: posterior predictive checks on all 480 G2 fits
# (docs/design_decisions.md, "v2 extension 1"; design locked in 3cc7e71 and
# 01d1b9c before any statistic below was computed). NO refitting: uses the
# per-cell posterior-mean predictions saved in each result's epred_summary
# and the observed counts in agg.
#
# Per fit:
#   stat1 aggregate RMSE  -- v1 definition (ppc_joint_counts.R): counts pooled
#                            over participants into 16 cells, proportions
#                            within stimulus, RMSE of observed - predicted
#   stat2 high-confidence -- mean |observed - predicted| over the 4
#                            confidence = 4 cells of stat1 (secondary,
#                            v1-motivated)
#   stat3 Pearson X2/df   -- over participant x cell, df = N*16 - N*2;
#                            never referred to a chi-square distribution
# Detection: per N x T x d' cell, threshold = 19th order statistic of the 20
# correct-family values (quantile type 1); misspecified fit detected if
# strictly greater. Pooled detection = mean of the 12 per-cell rates.
#
# Run from the project root: Rscript code/04_ppc_and_comparison/g2_ppc_all.R

suppressPackageStartupMessages(library(dplyr))
library(ggplot2)
set.seed(20260923)  # jitter positions are reproducible

out_data <- here::here("data", "processed", "v2")
out_fig <- here::here("outputs", "figures", "v2")
dir.create(out_data, recursive = TRUE, showWarnings = FALSE)
dir.create(out_fig, recursive = TRUE, showWarnings = FALSE)

# Column layout of agg$N for K = 4 (verified in ppc_joint_counts.R).
col_map <- tibble::tribble(
  ~stimulus, ~response, ~confidence, ~col,
  0, 0, 4, 1,  0, 0, 3, 2,  0, 0, 2, 3,  0, 0, 1, 4,
  0, 1, 1, 5,  0, 1, 2, 6,  0, 1, 3, 7,  0, 1, 4, 8,
  1, 0, 4, 9,  1, 0, 3, 10, 1, 0, 2, 11, 1, 0, 1, 12,
  1, 1, 1, 13, 1, 1, 2, 14, 1, 1, 3, 15, 1, 1, 4, 16
)

# Participant x cell table: observed count n, stimulus trial count n_s, and
# posterior-mean predicted probability p (conditional on stimulus).
participant_cells <- function(r) {
  agg <- r$agg
  obs <- purrr::pmap_dfr(col_map, function(stimulus, response, confidence, col) {
    n_s <- if (stimulus == 0) agg$N_0 else agg$N_1
    tibble::tibble(participant = agg$participant, stimulus = stimulus, response = response,
                   confidence = confidence, n = agg$N[, col], n_s = n_s)
  })
  ep <- r$epred_summary |>
    dplyr::transmute(participant, stimulus, response, confidence, p = epred_mean)
  out <- dplyr::inner_join(obs, ep, by = c("participant", "stimulus", "response", "confidence"))
  stopifnot(nrow(out) == nrow(obs), nrow(out) == nrow(ep))
  out
}

fit_statistics <- function(pc) {
  cells <- pc |>
    dplyr::group_by(stimulus, response, confidence) |>
    dplyr::summarise(observed_n = sum(n), predicted_n = sum(p * n_s), .groups = "drop") |>
    dplyr::group_by(stimulus) |>
    dplyr::mutate(total_n = sum(observed_n)) |>
    dplyr::ungroup() |>
    dplyr::mutate(discrepancy = observed_n / total_n - predicted_n / total_n)
  expected <- pc$n_s * pc$p
  n_part <- dplyr::n_distinct(pc$participant)
  tibble::tibble(
    stat1_rmse = sqrt(mean(cells$discrepancy^2)),
    stat2_highconf = mean(abs(cells$discrepancy[cells$confidence == 4])),
    stat3_x2_df = sum((pc$n - expected)^2 / expected) / (n_part * 16 - n_part * 2),
    prop_expected_lt5 = mean(expected < 5),
    prop_expected_lt1 = mean(expected < 1)
  )
}

# ---- Check before use: reproduce v1 stat1 for grid 1321/1322 ---------------
interim_dir <- here::here("data", "interim")
files <- list.files(interim_dir, pattern = "^g2_.*\\.qs2$", full.names = TRUE)
stopifnot(length(files) == 480)
grid_of <- function(f) as.integer(sub(".*grid-(\\d+)\\.qs2$", "\\1", f))

v1 <- readr::read_csv(here::here("data", "processed", "ppc_discrepancy_summary.csv"), show_col_types = FALSE)
v1_check <- tibble::tibble(grid_id = c(1321L, 1322L),
                           fit_label = c("G2 correct (Gumbel-min)", "G2 misspecified (Gaussian)"))
v1_check$recomputed <- vapply(v1_check$grid_id, function(g) {
  fit_statistics(participant_cells(qs2::qs_read(files[grid_of(files) == g])))$stat1_rmse
}, numeric(1))
v1_check <- dplyr::left_join(v1_check, v1, by = "fit_label")
v1_check$abs_diff <- abs(v1_check$recomputed - v1_check$rmse_discrepancy)
print(v1_check[, c("grid_id", "fit_label", "rmse_discrepancy", "recomputed", "abs_diff")])
if (any(v1_check$abs_diff > 1e-6)) stop("v1 check failed: stat1 does not reproduce ppc_discrepancy_summary.csv")
cat("v1 check passed (max abs diff ", signif(max(v1_check$abs_diff), 3), ")\n\n", sep = "")

# ---- Per-fit statistics (one pass over the 480 files) ----------------------
cat("Computing PPC statistics for", length(files), "G2 fits...\n")
by_fit <- purrr::map_dfr(files, function(f) {
  r <- qs2::qs_read(f)
  meta <- tibble::tibble(grid_id = r$grid_id, cell_id = r$cell_id, rep_id = r$rep_id,
                         fit_variant = r$fit_variant, n_participants = r$n_participants,
                         n_trials = r$n_trials, dprime_target = r$dprime_target,
                         status = r$status, has_epred = NROW(r$epred_summary) > 0)
  if (!meta$has_epred) return(meta)
  dplyr::bind_cols(meta, fit_statistics(participant_cells(r)))
})
by_fit <- by_fit |>
  dplyr::mutate(cell = sprintf("N=%d,T=%d,d'=%s", n_participants, n_trials, dprime_target)) |>
  dplyr::arrange(n_participants, n_trials, dprime_target, rep_id, fit_variant)
readr::write_csv(by_fit, file.path(out_data, "g2_ppc_by_fit.csv"))
cat("Status:", paste(names(table(by_fit$status)), table(by_fit$status), collapse = ", "),
    "| with epred_summary:", sum(by_fit$has_epred), "\n")

stats <- c("stat1_rmse", "stat2_highconf", "stat3_x2_df")
cell_keys <- c("n_participants", "n_trials", "dprime_target", "cell")

# ---- Paired comparison ----------------------------------------------------
long <- by_fit |>
  dplyr::filter(has_epred) |>
  tidyr::pivot_longer(dplyr::all_of(stats), names_to = "statistic", values_to = "value")
paired <- long |>
  dplyr::select(dplyr::all_of(cell_keys), cell_id, rep_id, fit_variant, status, statistic, value) |>
  tidyr::pivot_wider(names_from = fit_variant, values_from = c(value, status)) |>
  dplyr::filter(!is.na(value_correct), !is.na(value_misspecified)) |>
  dplyr::mutate(diff = value_misspecified - value_correct,
                ratio = value_misspecified / value_correct,
                mis_worse = value_misspecified > value_correct,
                both_pass = status_correct == "pass" & status_misspecified == "pass")
readr::write_csv(paired, file.path(out_data, "g2_ppc_paired.csv"))

summarise_paired <- function(d) {
  d |> dplyr::summarise(
    n_pairs = dplyr::n(), prop_mis_worse = mean(mis_worse),
    median_diff = stats::median(diff), diff_q05 = stats::quantile(diff, 0.05), diff_q95 = stats::quantile(diff, 0.95),
    median_ratio = stats::median(ratio), ratio_q05 = stats::quantile(ratio, 0.05), ratio_q95 = stats::quantile(ratio, 0.95),
    .groups = "drop")
}
paired_by_cell <- paired |> dplyr::group_by(statistic, dplyr::across(dplyr::all_of(cell_keys))) |> summarise_paired()
paired_overall <- paired |> dplyr::group_by(statistic) |> summarise_paired()

# ---- Calibrated (oracle) detection by cell ---------------------------------
wilson <- function(k, n) {
  ci <- stats::prop.test(k, n, correct = FALSE)$conf.int
  c(lo = ci[1], hi = ci[2])
}
loo <- readr::read_csv(here::here("data", "processed", "g2_elpd_summary.csv"), show_col_types = FALSE) |>
  dplyr::select(n_participants, n_trials, dprime_target, loo_prop_2se = prop_favors_correct_2se)

detect <- function(fits, require_20 = TRUE) {
  fits |>
    dplyr::group_by(statistic, dplyr::across(dplyr::all_of(cell_keys))) |>
    dplyr::group_modify(function(d, key) {
      ref <- d$value[d$fit_variant == "correct"]
      mis <- d$value[d$fit_variant == "misspecified"]
      if (require_20) stopifnot(length(ref) == 20)
      thr <- unname(stats::quantile(ref, 0.95, type = 1))
      k <- sum(mis > thr)
      ci <- wilson(k, length(mis))
      tibble::tibble(n_correct_ref = length(ref), threshold = thr, n_misspecified = length(mis),
                     n_detected = k, detection = k / length(mis), det_lo = ci[["lo"]], det_hi = ci[["hi"]],
                     false_alarm = mean(ref > thr))
    }) |>
    dplyr::ungroup() |>
    dplyr::left_join(loo, by = c("n_participants", "n_trials", "dprime_target"))
}
detection <- detect(long)
detection_by_cell <- detection |>
  dplyr::left_join(paired_by_cell, by = c("statistic", cell_keys)) |>
  dplyr::arrange(statistic, n_participants, n_trials, dprime_target)
readr::write_csv(detection_by_cell, file.path(out_data, "g2_ppc_detection_by_cell.csv"))

# Secondary view (statistic 3 only, not in the decision rule): one threshold
# pooled over all 240 correct fits.
s3 <- long |> dplyr::filter(statistic == "stat3_x2_df")
s3_thr <- unname(stats::quantile(s3$value[s3$fit_variant == "correct"], 0.95, type = 7))
s3_pooled_threshold_detection <- mean(s3$value[s3$fit_variant == "misspecified"] > s3_thr)

# ---- Verdict (decision rule, evaluated in order) ---------------------------
verdict_for <- function(det) {
  pooled <- det |> dplyr::group_by(statistic) |> dplyr::summarise(pooled = mean(detection), .groups = "drop")
  pd <- stats::setNames(pooled$pooled, pooled$statistic)
  max_cell <- det |> dplyr::group_by(statistic) |> dplyr::summarise(m = max(detection), .groups = "drop")
  mc <- stats::setNames(max_cell$m, max_cell$statistic)
  s1 <- det |> dplyr::filter(statistic == "stat1_rmse")
  n_below_loo <- sum(s1$detection < s1$loo_prop_2se)
  verdict <- if (pd[["stat1_rmse"]] >= 0.8) {
    "Reversed"
  } else if (any(mc[stats] >= 0.8)) {
    "Qualified"
  } else if (pd[["stat1_rmse"]] < 0.5 && pd[["stat3_x2_df"]] < 0.5 && n_below_loo >= 10) {
    "Kept"
  } else {
    "Mixed"
  }
  list(verdict = verdict, pooled = pd, max_cell = mc, n_cells_stat1_below_loo = n_below_loo,
       qualifying = det |> dplyr::filter(detection >= 0.8) |>
         dplyr::select(statistic, cell, detection, det_lo, det_hi, loo_prop_2se))
}
primary <- verdict_for(detection)

# Pass-only sensitivity: pairs where both fits passed; thresholds from the
# remaining correct fits in each cell (type 1 quantile, as in the primary).
pass_pairs <- paired |> dplyr::filter(both_pass) |> dplyr::distinct(cell_id)
long_pass <- long |> dplyr::filter(cell_id %in% pass_pairs$cell_id)
detection_pass <- detect(long_pass, require_20 = FALSE)
sensitivity <- verdict_for(detection_pass)

summary_tbl <- dplyr::bind_rows(
  tibble::tibble(analysis = "primary", statistic = stats,
                 pooled_detection = unname(primary$pooled[stats]), max_cell_detection = unname(primary$max_cell[stats]),
                 verdict = primary$verdict, n_cells_stat1_below_loo = primary$n_cells_stat1_below_loo),
  tibble::tibble(analysis = "pass_only", statistic = stats,
                 pooled_detection = unname(sensitivity$pooled[stats]), max_cell_detection = unname(sensitivity$max_cell[stats]),
                 verdict = sensitivity$verdict, n_cells_stat1_below_loo = sensitivity$n_cells_stat1_below_loo)
) |>
  dplyr::left_join(paired_overall |> dplyr::select(statistic, n_pairs, prop_mis_worse, median_diff, median_ratio),
                   by = "statistic") |>
  dplyr::mutate(stat3_pooled_threshold_detection = ifelse(statistic == "stat3_x2_df" & analysis == "primary",
                                                          s3_pooled_threshold_detection, NA_real_))
readr::write_csv(summary_tbl, file.path(out_data, "g2_ppc_summary.csv"))

# ---- Console report --------------------------------------------------------
cat("\n=== Paired comparison (all cells) ===\n")
print(as.data.frame(paired_overall), digits = 3)
cat("\n=== Detection by cell (oracle threshold) ===\n")
print(as.data.frame(detection_by_cell |>
  dplyr::select(statistic, cell, detection, det_lo, det_hi, false_alarm, loo_prop_2se, prop_mis_worse, median_ratio)),
  digits = 3)
cat("\nStat 3, single pooled threshold (secondary):", round(s3_pooled_threshold_detection, 3), "\n")
cat("Expected counts < 5: median proportion of participant x cell entries =",
    round(stats::median(by_fit$prop_expected_lt5, na.rm = TRUE), 3),
    "(range", paste(round(range(by_fit$prop_expected_lt5, na.rm = TRUE), 3), collapse = "-"), ")\n")
cat("\n=== Verdict ===\n")
print(as.data.frame(summary_tbl[, c("analysis", "statistic", "pooled_detection", "max_cell_detection", "verdict",
                                     "n_cells_stat1_below_loo")]), digits = 3)
if (nrow(primary$qualifying) > 0) {
  cat("\nCells with detection >= 0.8 (primary):\n")
  print(as.data.frame(primary$qualifying), digits = 3)
}

# ---- Figure -----------------------------------------------------------------
source(here::here("code", "05_figures", "fig_g2_ppc_all.R"))   # reads the CSVs written above
cat("\nWrote data/processed/v2/{g2_ppc_by_fit,g2_ppc_paired,g2_ppc_detection_by_cell,g2_ppc_summary}.csv\n")
cat("Wrote outputs/figures/v2/fig_g2_ppc_all.png\nDone.\n")
