# Posterior predictive checks for prespecified representative fits
# (protocol section 5, Day 5 morning):
#   - G0 typical pass
#   - G1 low-noise pass
#   - G1 high-noise pass (protocol also asks for a "failure where
#     possible" case, but G1 had a 100% pass rate across all 720
#     production fits -- no failure exists to show; documented, not
#     substituted with a cherry-picked worse fit)
#   - G2 correct-distribution fit
#   - G2 Gaussian-misspecified fit
# All five are the SAME representative condition (N=40, T=200, d'=1.5)
# already used for prior_sensitivity.R/sensitivity_binning.R, for
# methodological consistency across the project's robustness checks.
# Selected by prespecified category (generator/variant/sigma_c level),
# not by how good the result looks, and all have rep_id <= 2 so the
# full brmsfit is available (execution.keep_full_fit_max_rep_id).
#
# Uses hmetad::epred_draws_metad() for posterior-predicted joint
# response probabilities, unpacks aggregate_metad()'s N-matrix column
# layout (verified against direct trial-level counts, see
# docs/analysis_log.md) for observed counts, and compares both as
# proportions conditional on stimulus (each stimulus's 8 (R,C) cells
# sum to 1, matching the model's own likelihood structure).
#
# Run from the project root: Rscript code/04_ppc_and_comparison/ppc_joint_counts.R

suppressPackageStartupMessages(library(dplyr))

# hmetad's posterior_epred() for a gumbel_min-family fit looks up
# `gumbel_min_lcdf`/`gumbel_min_lccdf` by name in the calling R
# environment (not just the compiled Stan model) -- must be sourced
# even though no gumbel data is being simulated here.
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))

# Column layout for K=4 (see docs/analysis_log.md's compute_primary_metrics.R
# verification): N_0_1..N_0_4 = (S=0,R=0,C=4..1); N_0_5..N_0_8 = (S=0,R=1,C=1..4);
# N_1_1..N_1_4 = (S=1,R=0,C=4..1); N_1_5..N_1_8 = (S=1,R=1,C=1..4).
col_map <- tibble::tribble(
  ~stimulus, ~response, ~confidence, ~col,
  0, 0, 4, 1,  0, 0, 3, 2,  0, 0, 2, 3,  0, 0, 1, 4,
  0, 1, 1, 5,  0, 1, 2, 6,  0, 1, 3, 7,  0, 1, 4, 8,
  1, 0, 4, 9,  1, 0, 3, 10, 1, 0, 2, 11, 1, 0, 1, 12,
  1, 1, 1, 13, 1, 1, 2, 14, 1, 1, 3, 15, 1, 1, 4, 16
)

unpack_observed <- function(agg) {
  purrr::pmap_dfr(col_map, function(stimulus, response, confidence, col) {
    tibble::tibble(stimulus = stimulus, response = response, confidence = confidence,
                    observed_n = sum(agg$N[, col]))
  })
}

compute_predicted <- function(fit, agg) {
  ep <- hmetad::epred_draws_metad(fit, agg)
  ep_mean <- ep |>
    dplyr::group_by(participant, stimulus, response, confidence) |>
    dplyr::summarise(epred_mean = mean(.epred), .groups = "drop")

  agg_n <- agg |> dplyr::select(participant, N_0, N_1)
  dplyr::left_join(ep_mean, agg_n, by = "participant") |>
    dplyr::mutate(n_stim = ifelse(stimulus == 0, N_0, N_1),
                  predicted_n = epred_mean * n_stim) |>
    dplyr::group_by(stimulus, response, confidence) |>
    dplyr::summarise(predicted_n = sum(predicted_n), .groups = "drop")
}

build_ppc_table <- function(grid_id, fit_label, path) {
  r <- qs2::qs_read(path)
  stopifnot(!is.null(r$fit))  # requires the full brmsfit (rep_id <= 2)

  observed <- unpack_observed(r$agg)
  predicted <- compute_predicted(r$fit, r$agg)
  total_by_stim <- tibble::tibble(stimulus = c(0, 1), total_n = c(sum(r$agg$N_0), sum(r$agg$N_1)))

  dplyr::left_join(observed, predicted, by = c("stimulus", "response", "confidence")) |>
    dplyr::left_join(total_by_stim, by = "stimulus") |>
    dplyr::mutate(
      fit_label = fit_label, grid_id = grid_id,
      observed_prop = observed_n / total_n, predicted_prop = predicted_n / total_n,
      discrepancy = observed_prop - predicted_prop
    )
}

interim_dir <- here::here("data", "interim")
find_path <- function(grid_id) {
  files <- list.files(interim_dir, pattern = sprintf("grid-%05d\\.qs2$", grid_id), full.names = TRUE)
  stopifnot(length(files) == 1)
  files[1]
}

# Representative grid_ids, all N=40/T=200/d'=1.5, rep_id in {1,2}:
representative <- tibble::tribble(
  ~grid_id, ~fit_label,
  901,  "G0 (typical pass)",
  561,  "G1 low noise (pass)",
  541,  "G1 high noise (pass)",  # no G1 failures exist in the production grid -- see script header
  1321, "G2 correct (Gumbel-min)",
  1322, "G2 misspecified (Gaussian)"
)

cat("Building PPC tables for", nrow(representative), "representative fits...\n")
ppc_table <- purrr::pmap_dfr(representative, function(grid_id, fit_label) {
  cat(" -", fit_label, "(grid_id", grid_id, ")\n")
  build_ppc_table(grid_id, fit_label, find_path(grid_id))
})

readr::write_csv(ppc_table, here::here("data", "processed", "ppc_joint_counts.csv"))
cat("\nWrote data/processed/ppc_joint_counts.csv (", nrow(ppc_table), "rows )\n")

# --- Discrepancy summary per fit ---------------------------------------

discrepancy_summary <- ppc_table |>
  dplyr::group_by(fit_label) |>
  dplyr::summarise(
    max_abs_discrepancy = max(abs(discrepancy)),
    mean_abs_discrepancy = mean(abs(discrepancy)),
    rmse_discrepancy = sqrt(mean(discrepancy^2)),
    .groups = "drop"
  )
readr::write_csv(discrepancy_summary, here::here("data", "processed", "ppc_discrepancy_summary.csv"))
cat("\n=== PPC discrepancy summary ===\n")
print(discrepancy_summary, n = Inf)

# --- Plot: observed vs. predicted proportions per cell, by fit ---------

ppc_table$fit_label <- factor(ppc_table$fit_label, levels = representative$fit_label)
ppc_table$cell <- paste0("S", ppc_table$stimulus, "R", ppc_table$response, "C", ppc_table$confidence)

p1 <- ggplot2::ggplot(ppc_table, ggplot2::aes(x = predicted_prop, y = observed_prop)) +
  ggplot2::geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey50") +
  ggplot2::geom_point(ggplot2::aes(color = factor(stimulus)), size = 2) +
  ggplot2::facet_wrap(~fit_label, ncol = 3) +
  ggplot2::labs(
    title = "Posterior predictive check: observed vs. predicted joint response proportions",
    subtitle = "Each point = one (stimulus, response, confidence) cell; dashed line = perfect fit",
    x = "Posterior-predicted proportion (epred_draws_metad)", y = "Observed proportion",
    color = "Stimulus"
  ) +
  ggplot2::theme_minimal() +
  ggplot2::theme(legend.position = "bottom")

ggplot2::ggsave(here::here("outputs", "figures", "ppc_scatter.png"), p1, width = 10, height = 7, dpi = 150)

p2 <- ggplot2::ggplot(ppc_table, ggplot2::aes(x = cell, y = discrepancy, fill = factor(stimulus))) +
  ggplot2::geom_col() +
  ggplot2::geom_hline(yintercept = 0, color = "black") +
  ggplot2::facet_wrap(~fit_label, ncol = 1, scales = "free_x") +
  ggplot2::labs(
    title = "Posterior predictive discrepancy (observed - predicted proportion)",
    x = "Stimulus x Response x Confidence cell", y = "Discrepancy", fill = "Stimulus"
  ) +
  ggplot2::theme_minimal() +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, hjust = 1, size = 7), legend.position = "bottom")

ggplot2::ggsave(here::here("outputs", "figures", "ppc_discrepancy.png"), p2, width = 8, height = 12, dpi = 150)

cat("\nWrote outputs/figures/ppc_scatter.png and ppc_discrepancy.png\n")
cat("Done.\n")
