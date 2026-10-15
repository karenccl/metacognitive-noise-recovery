# v2 extension 2: replicated-data posterior predictive p-values on the 48
# G2 fits whose full brmsfit was kept (rep_id 1-2 x 12 cells x 2 families;
# docs/design_decisions.md, "v2 extension 2", locked in 32de75f before any
# statistic below was computed). NO refitting.
#
# For every posterior draw s: y_rep ~ Multinomial(n_ps, p_ps^(s)) per
# participant x stimulus (the aggregated likelihood used in fitting), and
# realised discrepancies T(y, theta_s), T(y_rep_s, theta_s) against the
# draw's own probabilities:
#   stat1 aggregate RMSE (primary), stat2 highest-confidence discrepancy,
#   stat3 participant-level Pearson X2/df (both secondary).
# p = mean(T_rep >= T_obs); flagged if p < 0.05.
#
# Run from the project root: Rscript code/04_ppc_and_comparison/g2_ppp_fullfits.R

suppressPackageStartupMessages(library(dplyr))
library(ggplot2)

# hmetad's epred for a gumbel_min fit looks up gumbel_min_lcdf/lccdf by name.
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))

seed_base <- yaml::read_yaml(here::here("config", "design.yml"))$seed_base
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
stats <- c("stat1_rmse", "stat2_highconf", "stat3_x2_df")
tol <- 1e-8

# ---- One fit ---------------------------------------------------------------
# Columns of every draw x column matrix are ordered participant, stimulus,
# response, confidence (confidence fastest), so each participant x stimulus
# group occupies 8 consecutive columns.
ppp_one_fit <- function(path) {
  r <- qs2::qs_read(path)
  if (is.null(r$fit) || !inherits(r$fit, "brmsfit")) stop("no brmsfit in ", basename(path))

  ep <- hmetad::epred_draws_metad(r$fit, r$agg) |>
    dplyr::ungroup() |>
    dplyr::arrange(.draw, participant, stimulus, response, confidence)
  n_draws <- dplyr::n_distinct(ep$.draw)
  n_cols <- nrow(ep) / n_draws
  stopifnot(n_cols == round(n_cols))
  P <- matrix(ep$.epred, nrow = n_draws, byrow = TRUE)

  # Column metadata from the first draw.
  cols <- ep |> dplyr::filter(.draw == min(.draw)) |>
    dplyr::select(participant, stimulus, response, confidence) |>
    dplyr::left_join(col_map, by = c("stimulus", "response", "confidence"))
  stopifnot(nrow(cols) == n_cols, !anyNA(cols$col))
  n_groups <- n_cols / 8
  group <- rep(seq_len(n_groups), each = 8)
  stopifnot(all(tapply(cols$stimulus, group, dplyr::n_distinct) == 1))

  # Precondition 1: per-draw probabilities sum to 1 within participant x stimulus.
  arr <- array(P, c(n_draws, 8, n_groups))
  sums <- apply(arr, c(1, 3), sum)
  if (max(abs(sums - 1)) > tol) stop("probabilities do not sum to 1: ", basename(path))

  # Precondition 2: mean over draws reproduces the stored epred_mean.
  stored <- r$epred_summary |>
    dplyr::select(participant, stimulus, response, confidence, epred_mean)
  chk <- cols |> dplyr::mutate(mean_draws = colMeans(P)) |>
    dplyr::left_join(stored, by = c("participant", "stimulus", "response", "confidence"))
  if (anyNA(chk$epred_mean) || max(abs(chk$mean_draws - chk$epred_mean)) > tol) {
    stop("draw means do not reproduce epred_summary: ", basename(path))
  }

  # Observed counts and per-column trial counts n_ps.
  agg <- r$agg
  pidx <- match(cols$participant, agg$participant)
  obs <- agg$N[cbind(pidx, cols$col)]
  n_ps <- ifelse(cols$stimulus == 0, agg$N_0[pidx], agg$N_1[pidx])
  stopifnot(all(tapply(obs, group, sum) == tapply(n_ps, group, unique)))

  # Aggregation to the 16 stimulus x response x confidence cells.
  cell16 <- cols$col
  A <- outer(cell16, 1:16, `==`) * 1
  cell_stim <- col_map$stimulus[order(col_map$col)]
  tot_by_cell <- ifelse(cell_stim == 0, sum(agg$N_0), sum(agg$N_1))
  conf4 <- col_map$col[col_map$confidence == 4]
  df3 <- n_groups / 2 * 16 - n_groups / 2 * 2  # N*16 - N*2, n_groups = 2N

  E <- sweep(P, 2, n_ps, `*`)  # expected counts per draw
  E16 <- E %*% A
  discrepancies <- function(Y) {  # Y: draws x columns of counts
    d16 <- sweep(Y %*% A - E16, 2, tot_by_cell, `/`)
    cbind(stat1_rmse = sqrt(rowMeans(d16^2)),
          stat2_highconf = rowMeans(abs(d16[, conf4, drop = FALSE])),
          stat3_x2_df = rowSums((Y - E)^2 / E) / df3)
  }

  # Replicated data: sequential conditional binomials = one multinomial per
  # draw x participant x stimulus.
  set.seed(seed_base + r$grid_id)
  n_rem <- matrix(rep(n_ps[seq(1, n_cols, by = 8)], each = n_draws), n_draws, n_groups)
  p_rem <- matrix(1, n_draws, n_groups)
  Yarr <- array(0L, c(n_draws, 8, n_groups))
  for (k in 1:7) {
    pk <- arr[, k, ]
    q <- pmin(pmax(pk / pmax(p_rem, 1e-300), 0), 1)
    yk <- matrix(stats::rbinom(length(n_rem), n_rem, q), n_draws, n_groups)
    Yarr[, k, ] <- yk
    n_rem <- n_rem - yk
    p_rem <- p_rem - pk
  }
  Yarr[, 8, ] <- n_rem
  Yrep <- matrix(Yarr, n_draws, n_cols)

  Yobs <- matrix(obs, n_draws, n_cols, byrow = TRUE)
  T_obs <- discrepancies(Yobs)
  T_rep <- discrepancies(Yrep)
  p <- colMeans(T_rep >= T_obs)

  tibble::tibble(grid_id = r$grid_id, cell_id = r$cell_id, rep_id = r$rep_id, fit_variant = r$fit_variant,
                 n_participants = r$n_participants, n_trials = r$n_trials, dprime_target = r$dprime_target,
                 status = r$status, n_draws = n_draws,
                 max_sum_dev = max(abs(sums - 1)), max_mean_dev = max(abs(chk$mean_draws - chk$epred_mean)),
                 p_stat1_rmse = p[["stat1_rmse"]], p_stat2_highconf = p[["stat2_highconf"]],
                 p_stat3_x2_df = p[["stat3_x2_df"]],
                 mean_obs_stat1 = mean(T_obs[, "stat1_rmse"]), mean_rep_stat1 = mean(T_rep[, "stat1_rmse"]))
}

# ---- Run over the 48 stored fits ------------------------------------------
files <- list.files(here::here("data", "interim"), pattern = "^g2_.*_rep-0[12]_.*[.]qs2$", full.names = TRUE)
stopifnot(length(files) == 48)
cat("Computing replicated-data PPP for", length(files), "fits...\n")
by_fit <- purrr::map_dfr(seq_along(files), function(i) {
  t0 <- Sys.time()
  out <- ppp_one_fit(files[i])
  cat(sprintf(" [%2d/48] grid %d %-12s p1=%.3f p2=%.3f p3=%.3f (%.0fs)\n", i, out$grid_id, out$fit_variant,
              out$p_stat1_rmse, out$p_stat2_highconf, out$p_stat3_x2_df,
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  out
})
cat(sprintf("Preconditions: max |sum - 1| = %.2e, max |mean - epred_mean| = %.2e\n",
            max(by_fit$max_sum_dev), max(by_fit$max_mean_dev)))

# Reference columns on the same datasets: oracle detection (extension 1) and LOO > 2 SE.
ppc1 <- readr::read_csv(here::here("data", "processed", "v2", "g2_ppc_by_fit.csv"), show_col_types = FALSE)
thr <- readr::read_csv(here::here("data", "processed", "v2", "g2_ppc_detection_by_cell.csv"), show_col_types = FALSE) |>
  dplyr::filter(statistic == "stat1_rmse") |>
  dplyr::select(n_participants, n_trials, dprime_target, threshold)
oracle <- ppc1 |>
  dplyr::filter(fit_variant == "misspecified") |>
  dplyr::inner_join(thr, by = c("n_participants", "n_trials", "dprime_target")) |>
  dplyr::transmute(cell_id, oracle_detected_stat1 = stat1_rmse > threshold)
loo <- readr::read_csv(here::here("data", "processed", "g2_elpd_comparison.csv"), show_col_types = FALSE) |>
  dplyr::select(cell_id, loo_favors_correct_2se = favors_correct_2se)
by_fit <- by_fit |>
  dplyr::mutate(flag_stat1_rmse = p_stat1_rmse < 0.05, flag_stat2_highconf = p_stat2_highconf < 0.05,
                flag_stat3_x2_df = p_stat3_x2_df < 0.05,
                cell = sprintf("N=%d,T=%d,d'=%s", n_participants, n_trials, dprime_target)) |>
  dplyr::left_join(oracle, by = "cell_id") |>
  dplyr::left_join(loo, by = "cell_id") |>
  dplyr::arrange(n_participants, n_trials, dprime_target, rep_id, fit_variant)
readr::write_csv(by_fit, file.path(out_data, "g2_ppp_by_fit.csv"))

# ---- Summaries --------------------------------------------------------------
wilson <- function(k, n) {
  ci <- stats::prop.test(k, n, correct = FALSE)$conf.int
  c(lo = ci[1], hi = ci[2])
}
rate_rows <- function(d, analysis) {
  purrr::map_dfr(stats, function(s) {
    purrr::map_dfr(c("misspecified", "correct"), function(v) {
      x <- d[[paste0("flag_", s)]][d$fit_variant == v]
      ci <- wilson(sum(x), length(x))
      tibble::tibble(analysis = analysis, split = "all", level = "all", statistic = s, fit_variant = v,
                     n_fits = length(x), n_flagged = sum(x), rate = mean(x), lo = ci[["lo"]], hi = ci[["hi"]])
    })
  })
}
split_rows <- function(d, var) {
  d |> dplyr::group_by(fit_variant, level = as.character(.data[[var]])) |>
    dplyr::summarise(dplyr::across(dplyr::starts_with("flag_"), sum), n_fits = dplyr::n(), .groups = "drop") |>
    tidyr::pivot_longer(dplyr::starts_with("flag_"), names_to = "statistic", values_to = "n_flagged") |>
    dplyr::mutate(analysis = "primary", split = var, statistic = sub("^flag_", "", statistic),
                  rate = n_flagged / n_fits)
}
verdict_for <- function(d) {
  k_cor <- sum(d$flag_stat1_rmse[d$fit_variant == "correct"])
  k_mis <- sum(d$flag_stat1_rmse[d$fit_variant == "misspecified"])
  n <- sum(d$fit_variant == "misspecified")
  # Thresholds are counts out of 24; for a smaller pass-only set they are
  # applied as the same proportions (2/24, 18/24, 6/24).
  v <- if (k_cor / n > 2 / 24) "Not interpretable"
       else if (k_mis / n >= 18 / 24) "Practical PPC detects"
       else if (k_mis / n <= 6 / 24) "Practical PPC misses"
       else "Partial"
  s2 <- sum(d$flag_stat2_highconf[d$fit_variant == "misspecified"]) / n >= 18 / 24 &&
        sum(d$flag_stat2_highconf[d$fit_variant == "correct"]) / n <= 2 / 24
  list(verdict = v, stat2_named = s2, k_cor = k_cor, k_mis = k_mis, n = n)
}

primary <- verdict_for(by_fit)
pass_ids <- by_fit |> dplyr::group_by(cell_id) |> dplyr::filter(all(status == "pass")) |> dplyr::pull(cell_id) |> unique()
pass_only <- by_fit |> dplyr::filter(cell_id %in% pass_ids)
sensitivity <- verdict_for(pass_only)

mis24 <- by_fit |> dplyr::filter(fit_variant == "misspecified")
refs <- tibble::tibble(
  analysis = "primary", split = "all", level = "all", fit_variant = "misspecified",
  statistic = c("oracle_stat1_ext1", "loo_2se"), n_fits = nrow(mis24),
  n_flagged = c(sum(mis24$oracle_detected_stat1), sum(mis24$loo_favors_correct_2se)))
refs$rate <- refs$n_flagged / refs$n_fits

summary_tbl <- dplyr::bind_rows(
  rate_rows(by_fit, "primary"),
  refs,
  split_rows(by_fit, "n_trials"),
  split_rows(by_fit, "n_participants"),
  rate_rows(pass_only, "pass_only")
) |>
  dplyr::mutate(verdict = ifelse(analysis == "pass_only", sensitivity$verdict, primary$verdict),
                stat2_named = ifelse(analysis == "pass_only", sensitivity$stat2_named, primary$stat2_named))
readr::write_csv(summary_tbl, file.path(out_data, "g2_ppp_summary.csv"))

cat("\n=== Flag rates (p < 0.05), out of 24 per family ===\n")
print(as.data.frame(summary_tbl |> dplyr::filter(analysis == "primary", split == "all") |>
                      dplyr::select(statistic, fit_variant, n_flagged, n_fits, rate, lo, hi)), digits = 3)
cat("\n=== By T and by N (flag counts) ===\n")
print(as.data.frame(summary_tbl |> dplyr::filter(split != "all") |>
                      dplyr::select(split, level, fit_variant, statistic, n_flagged, n_fits)), digits = 3)
cat("\n=== p-value distribution (median, IQR) ===\n")
print(as.data.frame(by_fit |> dplyr::group_by(fit_variant) |>
  dplyr::summarise(dplyr::across(dplyr::starts_with("p_stat"),
                                 list(med = stats::median, q25 = ~stats::quantile(.x, .25), q75 = ~stats::quantile(.x, .75))),
                   .groups = "drop")), digits = 3)
cat(sprintf("\nVerdict (primary): %s  [stat1 flags: Gaussian %d/%d, correct %d/%d]; stat 2 named: %s\n",
            primary$verdict, primary$k_mis, primary$n, primary$k_cor, primary$n, primary$stat2_named))
cat(sprintf("Verdict (pass-only, %d pairs): %s  [Gaussian %d, correct %d]\n",
            sensitivity$n, sensitivity$verdict, sensitivity$k_mis, sensitivity$k_cor))

# ---- Figure -----------------------------------------------------------------
source(here::here("code", "05_figures", "fig_g2_ppp.R"))   # reads the CSVs written above
cat("\nWrote data/processed/v2/{g2_ppp_by_fit,g2_ppp_summary}.csv and outputs/figures/v2/fig_g2_ppp.png\nDone.\n")
