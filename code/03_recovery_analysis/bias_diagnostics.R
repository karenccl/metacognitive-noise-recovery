# Post-hoc diagnostics from the saved compact draws (NO refitting).
# Added 2026-09-28 in response to review items 11-13; exploratory, not part
# of the pre-registered analysis plan.
#
#  (11) The small negative log_M bias in G0 and G2-correct: is it related to
#       each fit's posterior between-participant SD of log_M
#       (sd_participant__Intercept; the truth is 0, so any positive value is
#       prior/likelihood-driven), and does it differ for the posterior mean
#       vs median?
#  (12) G2: 95% interval coverage of the true log_M (-1) for the correct and
#       misspecified fits, by condition and pooled, with Wilson intervals.
#  (13) G2: bias/RMSE of the other population-level intercepts (dprime, c,
#       metacognitive-threshold gaps). CAVEAT: the dprime/c/gap parameters of
#       the Gumbel-min fit live on a different latent scale from the
#       Gaussian generating values passed to sim_metad_participant, so their
#       "errors" against the nominal generating values are only interpretable
#       for the correct-family fit; for the misspecified (Gaussian) fit they
#       measure compensation for the wrong link, not estimation error.
#
# Truths: log_M = -1; dprime = dprime_target; c = 0; gap intercepts = -1
# (mean_z_c2 = -1, treated here as the log-scale generating value -- if the
# gap parameterisation differs, the gap rows are only comparable across
# families, not to -1).
#
# Run from the project root:
#   Rscript code/03_recovery_analysis/bias_diagnostics.R

suppressPackageStartupMessages(library(dplyr))

LOG_M_TRUE <- yaml::read_yaml(here::here("config", "design.yml"))$truth$log_M
GAP_TRUE <- yaml::read_yaml(here::here("config", "design.yml"))$truth$mean_z_c2
files <- list.files(here::here("data", "interim"), pattern = "\\.qs2$", full.names = TRUE)
files <- files[grepl("^g[02]_", basename(files))]

one_fit <- function(path) {
  r <- qs2::qs_read(path)
  d <- r$draws_b_sd
  if (is.null(d)) return(NULL)
  q <- function(x) stats::quantile(x, c(0.025, 0.975), names = FALSE)
  gap_cols <- grep("^b_metac2(zero|one)[0-9]diff_Intercept$", names(d), value = TRUE)
  gap_draws <- rowMeans(as.matrix(d[, gap_cols]))
  tibble::tibble(
    grid_id = r$grid_id, generator = r$generator, fit_variant = r$fit_variant,
    n_participants = r$n_participants, n_trials = r$n_trials,
    dprime_target = r$dprime_target, rep_id = r$rep_id, status = r$status,
    logM_mean = mean(d$b_Intercept), logM_median = stats::median(d$b_Intercept),
    logM_lo = q(d$b_Intercept)[1], logM_hi = q(d$b_Intercept)[2],
    sd_logM_mean = mean(d$sd_participant__Intercept),
    sd_logM_median = stats::median(d$sd_participant__Intercept),
    dprime_mean = mean(d$b_dprime_Intercept),
    dprime_lo = q(d$b_dprime_Intercept)[1], dprime_hi = q(d$b_dprime_Intercept)[2],
    c_mean = mean(d$b_c_Intercept),
    c_lo = q(d$b_c_Intercept)[1], c_hi = q(d$b_c_Intercept)[2],
    gap_mean = mean(gap_draws), gap_lo = q(gap_draws)[1], gap_hi = q(gap_draws)[2]
  )
}

fits <- purrr::map_dfr(files, one_fit) |>
  dplyr::mutate(
    condition = paste(generator, fit_variant, sep = "/"),
    cell = sprintf("N%d_T%d_d%s", n_participants, n_trials, dprime_target),
    err_mean = logM_mean - LOG_M_TRUE,
    err_median = logM_median - LOG_M_TRUE,
    covered = logM_lo <= LOG_M_TRUE & LOG_M_TRUE <= logM_hi
  )
readr::write_csv(fits, here::here("data", "processed", "bias_fit_level.csv"))
cat(sprintf("Read %d fits (%s)\n", nrow(fits), paste(names(table(fits$condition)), table(fits$condition), collapse = "; ")))

wilson <- function(k, n) {
  ci <- stats::prop.test(k, n, correct = FALSE)$conf.int
  c(lo = ci[1], hi = ci[2])
}

# ---- (11) bias diagnosis ---------------------------------------------------
bias11 <- fits |>
  dplyr::group_by(condition) |>
  dplyr::summarise(
    n_fits = dplyr::n(),
    bias_posterior_mean = mean(err_mean),
    bias_posterior_median = mean(err_median),
    frac_fits_negative_mean = mean(err_mean < 0),
    mean_posterior_sd_logM = mean(sd_logM_mean),
    cor_err_vs_sd_pooled = stats::cor(err_mean, sd_logM_mean),
    spearman_err_vs_sd = stats::cor(err_mean, sd_logM_mean, method = "spearman"),
    .groups = "drop"
  )
# within-cell correlation (removes between-cell differences in both quantities)
within <- fits |>
  dplyr::group_by(condition, cell) |>
  dplyr::summarise(cor_within = suppressWarnings(stats::cor(err_mean, sd_logM_mean)), .groups = "drop") |>
  dplyr::group_by(condition) |>
  dplyr::summarise(median_within_cell_cor = stats::median(cor_within, na.rm = TRUE),
                   min_within = min(cor_within, na.rm = TRUE), max_within = max(cor_within, na.rm = TRUE),
                   .groups = "drop")
bias11 <- dplyr::left_join(bias11, within, by = "condition")
readr::write_csv(bias11, here::here("data", "processed", "bias_diagnosis_summary.csv"))
cat("\n=== (11) log_M bias vs posterior between-participant SD ===\n")
print(as.data.frame(bias11), digits = 3)

by_n <- fits |>
  dplyr::filter(generator == "g0" | fit_variant == "correct") |>
  dplyr::group_by(generator, n_participants, n_trials) |>
  dplyr::summarise(bias_mean = mean(err_mean), bias_median = mean(err_median),
                   mean_sd = mean(sd_logM_mean), .groups = "drop")
cat("\nBias by N x T (G0 and G2-correct pooled by generator):\n")
print(as.data.frame(by_n), digits = 3)
readr::write_csv(by_n, here::here("data", "processed", "bias_by_sample_size.csv"))

# ---- (12) G2 coverage ------------------------------------------------------
cov_cell <- fits |>
  dplyr::filter(generator == "g2") |>
  dplyr::group_by(fit_variant, cell) |>
  dplyr::summarise(n_reps = dplyr::n(), n_covered = sum(covered), coverage = mean(covered), .groups = "drop") |>
  dplyr::rowwise() |>
  dplyr::mutate(ci_lo = wilson(n_covered, n_reps)["lo"], ci_hi = wilson(n_covered, n_reps)["hi"]) |>
  dplyr::ungroup()
cov_pooled <- fits |>
  dplyr::filter(generator == "g2") |>
  dplyr::group_by(fit_variant) |>
  dplyr::summarise(cell = "POOLED", n_reps = dplyr::n(), n_covered = sum(covered), coverage = mean(covered), .groups = "drop") |>
  dplyr::rowwise() |>
  dplyr::mutate(ci_lo = wilson(n_covered, n_reps)["lo"], ci_hi = wilson(n_covered, n_reps)["hi"]) |>
  dplyr::ungroup()
g2_cov <- dplyr::bind_rows(cov_cell, cov_pooled)
readr::write_csv(g2_cov, here::here("data", "processed", "g2_coverage.csv"))
cat("\n=== (12) G2 95% coverage of true log_M = -1 ===\n")
print(as.data.frame(g2_cov), digits = 3)

# ---- (13) nuisance-parameter recovery -------------------------------------
recov <- function(df) {
  df |>
    dplyr::mutate(
      e_dprime = dprime_mean - dprime_target, e_c = c_mean - 0, e_gap = gap_mean - GAP_TRUE,
      cov_dprime = dprime_lo <= dprime_target & dprime_target <= dprime_hi,
      cov_c = c_lo <= 0 & 0 <= c_hi,
      cov_gap = gap_lo <= GAP_TRUE & GAP_TRUE <= gap_hi
    ) |>
    dplyr::group_by(condition) |>
    dplyr::summarise(
      n_fits = dplyr::n(),
      dprime_bias = mean(e_dprime), dprime_rmse = sqrt(mean(e_dprime^2)), dprime_cov = mean(cov_dprime),
      c_bias = mean(e_c), c_rmse = sqrt(mean(e_c^2)), c_cov = mean(cov_c),
      gap_bias = mean(e_gap), gap_rmse = sqrt(mean(e_gap^2)), gap_cov = mean(cov_gap),
      .groups = "drop"
    )
}
nuis <- recov(fits)
readr::write_csv(nuis, here::here("data", "processed", "g2_nuisance_recovery.csv"))
cat("\n=== (13) Other population-level intercepts (vs nominal generating values) ===\n")
print(as.data.frame(nuis), digits = 3)
cat("\nDone. Wrote bias_fit_level.csv, bias_diagnosis_summary.csv, bias_by_sample_size.csv, g2_coverage.csv, g2_nuisance_recovery.csv\n")
