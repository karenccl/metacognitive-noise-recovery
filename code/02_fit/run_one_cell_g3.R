# v3 G3 entry point (docs/v3_plan.md §4.5): simulate the difficulty mixture for
# one row of config/grid_g3.csv, fit one of four variants, save to
# data/interim/v3_g3/. Resumable (skips existing output); same escalation
# policy as run_one_cell.R. Full brmsfit kept for rep_id <= keep_full_fit_max_rep_id.
#
# Usage: Rscript code/02_fit/run_one_cell_g3.R <g3_id>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: Rscript run_one_cell_g3.R <g3_id>")
g3_id <- as.integer(args[1])

suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))   # gumbel_min_* + stanvars
source(here::here("code", "01_simulate", "simulate_g3_mixture.R"))
source(here::here("code", "02_fit", "extract_fit_summary.R"))
source(here::here("code", "02_fit", "fit_hmetad.R"))

cfg  <- yaml::read_yaml(here::here("config", "design.yml"))
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml"))
grid <- readr::read_csv(here::here("config", "grid_g3.csv"), show_col_types = FALSE)
row  <- as.list(grid[grid$g3_id == g3_id, ])
if (length(row$g3_id) != 1) stop("g3_id ", g3_id, " not found (or not unique) in config/grid_g3.csv")

out_dir  <- here::here("data", "interim", "v3_g3")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_path <- file.path(out_dir, sprintf("g3_%s_rep-%02d_%s_id-%03d.qs2",
                                       row$condition, row$rep_id, row$fit_variant, row$g3_id))
if (file.exists(out_path)) { cat("exists:", out_path, "\n"); quit(save = "no") }

spec <- switch(row$fit_variant,
  normal_pooled     = list(dist = "normal",     agg_by = NULL,         cov = NULL),
  gumbel_pooled     = list(dist = "gumbel_min", agg_by = NULL,         cov = NULL),
  normal_difficulty = list(dist = "normal",     agg_by = "difficulty", cov = "difficulty"),
  gumbel_difficulty = list(dist = "gumbel_min", agg_by = "difficulty", cov = "difficulty"),
  stop("unknown fit_variant: ", row$fit_variant))

result <- tryCatch({
  data <- simulate_g3_mixture(
    n_participants = cfg3$g3$n_participants,
    n_trials_per_level = cfg3$g3$n_trials_per_level,
    dprimes = unlist(cfg3$g3$conditions[[row$condition]]),
    log_M = cfg$truth$log_M, k = cfg$confidence$k, seed = row$sim_seed)

  fit_once <- function(adapt_delta, max_treedepth, seed) fit_one_hmetad(
    data, K = cfg$confidence$k, group = "participant",
    distribution = spec$dist, metac_absolute = cfg$fitting$metac_absolute,
    hierarchical_dprime_c = cfg$fitting$hierarchical_dprime_c,
    hierarchical_thresholds = cfg$fitting$hierarchical_thresholds,
    log_M_prior = cfg$priors$log_M_production, metac2_prior = cfg$priors$metac2_gap,
    agg_by = spec$agg_by, dprime_c_covariates = spec$cov,
    chains = cfg$sampling$chains, warmup = cfg$sampling$warmup,
    iter_sampling = cfg$sampling$iter_sampling,
    adapt_delta = adapt_delta, max_treedepth = max_treedepth,
    rhat_max = cfg$diagnostics$rhat_max, bulk_ess_min = cfg$diagnostics$bulk_ess_min,
    tail_ess_min = cfg$diagnostics$tail_ess_min,
    seed = seed,
    extra_stanvars = if (spec$dist == "gumbel_min") gumbel_min_stanvars() else NULL,
    metadata = row)

  a <- fit_once(cfg$sampling$adapt_delta, cfg$sampling$max_treedepth, row$fit_seed)
  a$escalated <- FALSE
  if (identical(a$status, "refit")) {
    a <- fit_once(cfg$sampling$escalation$adapt_delta, cfg$sampling$escalation$max_treedepth,
                  row$fit_seed + 1L)
    a$escalated <- TRUE
    if (identical(a$status, "refit")) a$status <- "fail"
  }
  if (!is.null(a$fit)) {
    dr <- posterior::as_draws_df(a$fit)
    a$draws_b_sd <- tibble::as_tibble(dr[, grep("^b_|^sd_", names(dr), value = TRUE)])
    a$loo <- tryCatch(brms::loo(a$fit), error = function(e) NULL)
  }
  if (row$rep_id > cfg$execution$keep_full_fit_max_rep_id) a$fit <- NULL
  a
}, error = function(e) list(status = "error", error_message = conditionMessage(e), fit = NULL))

result$g3_id <- row$g3_id
qs2::qs_save(result, out_path)
cat("Saved", out_path, "status:", result$status, "\n")
