# v3 check of the post-registration empirical configuration (docs/analysis_log.md
# 2026-10-01): refit G0/G2 grid rows with the settings used for the Confidence
# Database fits -- sd_prior normal(0, 0.5) on every participant-level SD,
# hierarchical thresholds, 2000 + 2000 draws, init_r 0.5, adapt_delta 0.99
# (escalation 0.999 / 14) -- on the SAME simulated datasets (grid sim_seed) as the
# stored v1 fits, so recovery and coverage can be compared pair by pair.
#
# Usage:   Rscript code/03_recovery_analysis/v3_sdprior_validation.R <grid_id>
# Batch:   Rscript code/03_recovery_analysis/v3_sdprior_validation.R --shard <s> <n>
#          (all rows with N = 40, T = 200, rep 1-5, generators g0 and g2)

suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "01_simulate", "simulate_g0.R"))
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "02_fit", "extract_fit_summary.R"))
source(here::here("code", "02_fit", "fit_hmetad.R"))
cfg  <- yaml::read_yaml(here::here("config", "design.yml"))
e    <- yaml::read_yaml(here::here("config", "v3.yml"))$empirical
grid <- readr::read_csv(here::here("config", "grid.csv"), show_col_types = FALSE)
out_dir <- here::here("data", "interim", "v3_sdprior_val")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

val_ids <- grid |>
  filter(generator %in% c("g0", "g2"), n_participants == 40, n_trials == 200, rep_id <= 5) |>
  pull(grid_id) |> sort()

args <- commandArgs(trailingOnly = TRUE)
ids <- if (length(args) >= 3 && args[1] == "--shard") {
  s <- as.integer(args[2]); n <- as.integer(args[3])
  val_ids[(seq_along(val_ids) - 1L) %% n == (s - 1L)]
} else as.integer(args[1])
stopifnot(length(ids) >= 1, all(ids %in% val_ids))

for (id in ids) {
  row <- as.list(grid[grid$grid_id == id, ])
  out_path <- file.path(out_dir, sprintf("val_grid-%05d.qs2", id))
  if (file.exists(out_path)) { cat("exists", id, "\n"); next }
  data <- if (row$generator == "g0") {
    simulate_g0(row$n_participants, row$n_trials, row$dprime_target, cfg$truth$log_M,
                k = cfg$confidence$k, seed = row$sim_seed)
  } else {
    simulate_g2_gumbel(row$n_participants, row$n_trials, row$dprime_target, cfg$truth$log_M,
                       k = cfg$confidence$k, seed = row$sim_seed)
  }
  dist <- if (row$generator == "g2" && row$fit_variant == "correct") "gumbel_min" else "normal"
  fit_once <- function(adapt_delta, max_treedepth, seed) fit_one_hmetad(
    data, K = cfg$confidence$k, group = "participant",
    distribution = dist, metac_absolute = cfg$fitting$metac_absolute,
    hierarchical_dprime_c = TRUE, hierarchical_thresholds = e$hierarchical_thresholds,
    log_M_prior = cfg$priors$log_M_production, metac2_prior = cfg$priors$metac2_gap,
    sd_prior = e$sd_prior, chains = cfg$sampling$chains,
    warmup = e$warmup, iter_sampling = e$iter_sampling,
    adapt_delta = adapt_delta, max_treedepth = max_treedepth,
    rhat_max = cfg$diagnostics$rhat_max, bulk_ess_min = cfg$diagnostics$bulk_ess_min,
    tail_ess_min = cfg$diagnostics$tail_ess_min, seed = seed,
    extra_stanvars = if (dist == "gumbel_min") gumbel_min_stanvars() else NULL,
    metadata = row, init_r = e$init_r)
  a <- tryCatch(fit_once(e$adapt_delta_start, cfg$sampling$max_treedepth, row$fit_seed),
                error = function(err) list(status = "error", fit = NULL, error_message = conditionMessage(err)))
  a$escalated <- FALSE
  if (identical(a$status, "refit")) {
    a <- fit_once(e$escalation$adapt_delta, e$escalation$max_treedepth, row$fit_seed + 1L)
    a$escalated <- TRUE
    if (identical(a$status, "refit")) a$status <- "fail"
  }
  x <- if (!is.null(a$fit)) posterior::as_draws_df(a$fit)$b_Intercept else NA_real_
  rec <- c(row[c("grid_id", "cell_id", "generator", "fit_variant", "n_participants", "n_trials",
                 "dprime_target", "rep_id", "sim_seed")],
           list(status = a$status, escalated = a$escalated, diagnostics = a$diagnostics,
                log_M_mean = mean(x), log_M_q025 = quantile(x, .025, names = FALSE, na.rm = TRUE),
                log_M_q975 = quantile(x, .975, names = FALSE, na.rm = TRUE),
                elapsed_secs = a$elapsed_secs))
  qs2::qs_save(rec, out_path)
  cat(sprintf("grid %d %s %s d'=%s rep %d: %s log_M=%.3f\n", id, row$generator, row$fit_variant,
              row$dprime_target, row$rep_id, rec$status, rec$log_M_mean))
}
