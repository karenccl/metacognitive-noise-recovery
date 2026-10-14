# v3b runner for work packages C (two_group) and D (g4). Resumable, shardable.
# Usage: Rscript code/02_fit/run_v3b_jobs.R <job_id>
#        Rscript code/02_fit/run_v3b_jobs.R --shard <s> <n>
# Fits use the v1 production settings (config/design.yml), matching G2.

suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "01_simulate", "simulate_v3b_two_group.R"))
g4_file <- here::here("code", "01_simulate", "simulate_g4_uv.R")
if (file.exists(g4_file)) source(g4_file)
source(here::here("code", "02_fit", "extract_fit_summary.R"))
source(here::here("code", "02_fit", "fit_hmetad.R"))

cfg  <- yaml::read_yaml(here::here("config", "design.yml"))
cfgb <- yaml::read_yaml(here::here("config", "v3b.yml"))
grid <- readr::read_csv(here::here("config", "grid_v3b.csv"), show_col_types = FALSE)
out_dir <- here::here("data", "interim", "v3b")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

args <- commandArgs(trailingOnly = TRUE)
ids <- if (length(args) >= 3 && args[1] == "--shard") {
  s <- as.integer(args[2]); n <- as.integer(args[3])
  grid$job_id[(grid$job_id - 1L) %% n == (s - 1L)]
} else as.integer(args[1])
stopifnot(length(ids) >= 1, all(ids %in% grid$job_id))

simulate_job <- function(row) {
  if (row$study == "two_group") {
    tg <- cfgb$two_group
    simulate_two_group_g2(tg$n_per_group, tg$n_trials, unlist(tg$dprime_groups),
                          log_M = cfg$truth$log_M, k = cfg$confidence$k, seed = row$sim_seed)
  } else if (row$study == "g4") {
    if (!exists("simulate_g4_uv")) stop("simulate_g4_uv.R not written yet (work package D)")
    g4 <- cfgb$g4
    simulate_g4_uv(g4$n_participants, g4$n_trials, dprime = row$dprime,
                   sigma_ratio = g4$sigma_ratio[[row$condition]], sigma_meta = g4$sigma_meta,
                   conf_thresholds = unlist(g4$conf_thresholds),
                   sd_threshold_jitter = g4$sd_threshold_jitter,
                   sd_criterion = g4$sd_criterion, seed = row$sim_seed)
  } else stop("unknown study: ", row$study)
}

fit_job <- function(row, data) {
  dist <- if (row$fit_variant %in% c("correct", "gumbel_min")) "gumbel_min" else "normal"
  two  <- row$study == "two_group"
  once <- function(adapt_delta, max_treedepth, seed) fit_one_hmetad(
    data, K = cfg$confidence$k, group = "participant",
    distribution = dist, metac_absolute = cfg$fitting$metac_absolute,
    hierarchical_dprime_c = cfg$fitting$hierarchical_dprime_c,
    hierarchical_thresholds = cfg$fitting$hierarchical_thresholds,
    log_M_prior = cfg$priors$log_M_production, metac2_prior = cfg$priors$metac2_gap,
    agg_by = if (two) "group" else NULL,
    dprime_c_covariates = if (two) "group" else NULL,
    log_M_covariates = if (two) "group" else NULL,
    chains = cfg$sampling$chains, warmup = cfg$sampling$warmup,
    iter_sampling = cfg$sampling$iter_sampling,
    adapt_delta = adapt_delta, max_treedepth = max_treedepth,
    rhat_max = cfg$diagnostics$rhat_max, bulk_ess_min = cfg$diagnostics$bulk_ess_min,
    tail_ess_min = cfg$diagnostics$tail_ess_min, seed = seed,
    extra_stanvars = if (dist == "gumbel_min") gumbel_min_stanvars() else NULL,
    metadata = row)
  a <- once(cfg$sampling$adapt_delta, cfg$sampling$max_treedepth, row$fit_seed)
  a$escalated <- FALSE
  if (identical(a$status, "refit")) {
    a <- once(cfg$sampling$escalation$adapt_delta, cfg$sampling$escalation$max_treedepth,
              row$fit_seed + 1L)
    a$escalated <- TRUE
    if (identical(a$status, "refit")) a$status <- "fail"
  }
  a
}

for (id in ids) {
  row <- as.list(grid[grid$job_id == id, ])
  out_path <- file.path(out_dir, sprintf("%s_%s_d%s_rep-%02d_%s_job-%03d.qs2",
                                         row$study, row$condition,
                                         ifelse(is.na(row$dprime), "NA", format(row$dprime)),
                                         row$rep_id, row$fit_variant, id))
  if (file.exists(out_path)) { cat("exists", id, "\n"); next }
  t0 <- Sys.time()
  rec <- tryCatch({
    data <- simulate_job(row)
    stopifnot(max(data$confidence) <= cfg$confidence$k)
    a <- fit_job(row, data)
    if (!is.null(a$fit)) {
      dr <- posterior::as_draws_df(a$fit)
      a$draws_b_sd <- tibble::as_tibble(dr[, grep("^b_|^sd_", names(dr), value = TRUE)])
      if (row$study == "g4") a$loo <- tryCatch(brms::loo(a$fit), error = function(e) NULL)
    }
    a$fit <- NULL                       # compact record only
    a
  }, error = function(e) list(status = "error", error_message = conditionMessage(e)))
  rec$job <- row
  qs2::qs_save(rec, out_path)
  cat(sprintf("job %3d %-9s %-3s %-12s rep %2d: %s (%.0f s)\n", id, row$study, row$condition,
              row$fit_variant, row$rep_id, rec$status,
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
