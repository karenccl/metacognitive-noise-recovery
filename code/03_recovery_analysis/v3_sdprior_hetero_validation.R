# v3 check of the sd_prior deviation under BETWEEN-PARTICIPANT HETEROGENEITY
# (docs/analysis_log.md 2026-10-01). The G0/G2 check (v3_sdprior_validation.R)
# used simulators with sd_M = sd_dprime = 0, the most favourable case for a prior
# that pulls SDs towards 0. Here G0-type Gaussian data have sd_M = 0.5 (log scale)
# and sd_dprime = 0.3; each dataset is fitted twice under the empirical
# configuration, once with brms's default SD prior and once with
# config/v3.yml$empirical$sd_prior, everything else identical.
#
# Usage: Rscript code/03_recovery_analysis/v3_sdprior_hetero_validation.R [--shard <s> <n>]
#        then the summary at the bottom runs when all 10 records exist.

suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "02_fit", "extract_fit_summary.R"))
source(here::here("code", "02_fit", "fit_hmetad.R"))
cfg  <- yaml::read_yaml(here::here("config", "design.yml"))
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml")); e <- cfg3$empirical
out_dir <- here::here("data", "interim", "v3_sdprior_hetero")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

design <- list(n_participants = 40, n_trials = 200, dprime = 1.5, sd_dprime = 0.3,
               log_M = cfg$truth$log_M, sd_M = 0.5, reps = 5)
jobs <- tidyr::expand_grid(rep_id = seq_len(design$reps), prior = c("default", "sd_prior")) |>
  mutate(job = row_number(), sim_seed = cfg3$seed_base_v3 + 500L + rep_id,
         fit_seed = sim_seed + 1000000L)

simulate_hetero <- function(seed, k = cfg$confidence$k) {
  z <- k - 1
  withr::with_seed(seed, hmetad::sim_metad_participant(
    N_participants = design$n_participants, N_trials = design$n_trials,
    mean_dprime = design$dprime, sd_dprime = design$sd_dprime,
    mean_c = 0, sd_c = 0, mean_M = design$log_M, sd_M = design$sd_M,
    mean_z_c2_0 = rep(-1, z), sd_z_c2_0 = rep(0.1, z),
    mean_z_c2_1 = rep(-1, z), sd_z_c2_1 = rep(0.1, z),
    r_z_c2_0 = diag(z), r_z_c2_1 = diag(z),
    metac_absolute = TRUE, allow_negative_values = FALSE, summarize = FALSE))
}

args <- commandArgs(trailingOnly = TRUE)
todo <- if (length(args) >= 3 && args[1] == "--shard") {
  s <- as.integer(args[2]); n <- as.integer(args[3]); jobs$job[(jobs$job - 1L) %% n == (s - 1L)]
} else jobs$job

for (j in todo) {
  jb <- jobs[jobs$job == j, ]
  out_path <- file.path(out_dir, sprintf("hetero_rep-%02d_%s.qs2", jb$rep_id, jb$prior))
  if (file.exists(out_path)) next
  data <- simulate_hetero(jb$sim_seed)
  fit_once <- function(adapt_delta, max_treedepth, seed) fit_one_hmetad(
    data, K = cfg$confidence$k, group = "participant", distribution = "normal",
    metac_absolute = TRUE, hierarchical_dprime_c = TRUE,
    hierarchical_thresholds = e$hierarchical_thresholds,
    log_M_prior = cfg$priors$log_M_production, metac2_prior = cfg$priors$metac2_gap,
    sd_prior = if (jb$prior == "sd_prior") e$sd_prior else NULL,
    chains = cfg$sampling$chains, warmup = e$warmup, iter_sampling = e$iter_sampling,
    adapt_delta = adapt_delta, max_treedepth = max_treedepth,
    rhat_max = cfg$diagnostics$rhat_max, bulk_ess_min = cfg$diagnostics$bulk_ess_min,
    tail_ess_min = cfg$diagnostics$tail_ess_min, seed = seed, init_r = e$init_r,
    metadata = as.list(jb))
  a <- tryCatch(fit_once(e$adapt_delta_start, cfg$sampling$max_treedepth, jb$fit_seed),
                error = function(err) list(status = "error", fit = NULL))
  a$escalated <- FALSE
  if (identical(a$status, "refit")) {
    a <- fit_once(e$escalation$adapt_delta, e$escalation$max_treedepth, jb$fit_seed + 1L)
    a$escalated <- TRUE
    if (identical(a$status, "refit")) a$status <- "fail"
  }
  dr <- if (!is.null(a$fit)) posterior::as_draws_df(a$fit) else NULL
  q <- function(x, p) if (is.null(x)) NA_real_ else quantile(x, p, names = FALSE)
  rec <- c(as.list(jb), list(status = a$status, escalated = a$escalated,
    max_rhat = if (is.null(a$diagnostics)) NA_real_ else a$diagnostics$max_rhat,
    n_div = if (is.null(a$diagnostics)) NA_real_ else a$diagnostics$n_divergent,
    logM_mean = mean(dr$b_Intercept), logM_q025 = q(dr$b_Intercept, .025), logM_q975 = q(dr$b_Intercept, .975),
    sdM_mean = mean(dr$sd_participant__Intercept), sdM_q025 = q(dr$sd_participant__Intercept, .025),
    sdM_q975 = q(dr$sd_participant__Intercept, .975),
    sdD_mean = mean(dr$sd_participant__dprime_Intercept),
    sdD_q025 = q(dr$sd_participant__dprime_Intercept, .025), sdD_q975 = q(dr$sd_participant__dprime_Intercept, .975)))
  qs2::qs_save(rec, out_path)
  cat(sprintf("rep %d %-8s %s logM=%.3f sdM=%.3f [%.2f, %.2f]\n", jb$rep_id, jb$prior, rec$status,
              rec$logM_mean, rec$sdM_mean, rec$sdM_q025, rec$sdM_q975))
}

# ---- summary (when all records exist) --------------------------------------
files <- list.files(out_dir, "[.]qs2$", full.names = TRUE)
if (length(files) == nrow(jobs)) {
  r <- purrr::map_dfr(files, ~ tibble::as_tibble(qs2::qs_read(.x)))
  readr::write_csv(r, here::here("data", "processed", "v3", "sdprior_hetero_by_fit.csv"))
  s <- r |> group_by(prior) |>
    summarise(n = n(), n_pass = sum(status == "pass"),
              logM_bias = mean(logM_mean - design$log_M),
              logM_cover = mean(logM_q025 <= design$log_M & design$log_M <= logM_q975),
              sdM_mean = mean(sdM_mean), sdM_bias = mean(sdM_mean - design$sd_M),
              sdM_cover = mean(sdM_q025 <= design$sd_M & design$sd_M <= sdM_q975),
              sdD_mean = mean(sdD_mean), sdD_cover = mean(sdD_q025 <= design$sd_dprime & design$sd_dprime <= sdD_q975),
              .groups = "drop")
  readr::write_csv(s, here::here("data", "processed", "v3", "sdprior_hetero_summary.csv"))
  print(as.data.frame(s), digits = 3)
}
