# v3 empirical step 5.7 (docs/v3_plan.md): fit one prepared dataset with one
# type-2 noise family. Hierarchical thresholds (config/v3.yml); with more than
# one condition level the data are aggregated by participant x condition and
# condition enters dprime, c and log_M. The full brmsfit is kept (needed for
# LOO repair and PPC). Both families of a dataset share one seed.
#
# Usage: Rscript code/06_empirical/04_fit_dataset.R <dataset> <normal|gumbel_min>

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2, args[2] %in% c("normal", "gumbel_min"))
dataset <- args[1]; family <- args[2]

suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "02_fit", "extract_fit_summary.R"))
source(here::here("code", "02_fit", "fit_hmetad.R"))
cfg  <- yaml::read_yaml(here::here("config", "design.yml"))
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml")); e <- cfg3$empirical

prep <- qs2::qs_read(here::here("data", "interim", "v3_empirical", "prepared", paste0(dataset, ".qs2")))
out_dir <- here::here("data", "interim", "v3_empirical", "fits")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_path <- file.path(out_dir, sprintf("%s__%s.qs2", dataset, family))
if (file.exists(out_path)) { cat("exists\n"); quit(save = "no") }

multi_cond <- nlevels(prep$data$condition) > 1
# Same seed for both families of a dataset: derived from the dataset name only.
seed <- cfg3$seed_base_v3 + sum(utf8ToInt(dataset)) * 7L
# Optional logged deviation (plan §5.7): a higher starting adapt_delta.
adapt_start <- if (is.null(e$adapt_delta_start)) cfg$sampling$adapt_delta else e$adapt_delta_start

fit_once <- function(adapt_delta, max_treedepth, seed) fit_one_hmetad(
  prep$data, K = prep$K, group = "participant",
  distribution = family, metac_absolute = cfg$fitting$metac_absolute,
  hierarchical_dprime_c = TRUE,
  hierarchical_thresholds = e$hierarchical_thresholds,       # TRUE for real data
  log_M_prior = cfg$priors$log_M_production, metac2_prior = cfg$priors$metac2_gap,
  agg_by = if (multi_cond) "condition" else NULL,
  dprime_c_covariates = if (multi_cond) "condition" else NULL,
  log_M_covariates = if (multi_cond) "condition" else NULL,
  sd_prior = e$sd_prior,
  chains = cfg$sampling$chains,
  warmup = if (is.null(e$warmup)) cfg$sampling$warmup else e$warmup,
  iter_sampling = if (is.null(e$iter_sampling)) cfg$sampling$iter_sampling else e$iter_sampling,
  adapt_delta = adapt_delta, max_treedepth = max_treedepth,
  rhat_max = cfg$diagnostics$rhat_max, bulk_ess_min = cfg$diagnostics$bulk_ess_min,
  tail_ess_min = cfg$diagnostics$tail_ess_min, seed = seed,
  extra_stanvars = if (family == "gumbel_min") gumbel_min_stanvars() else NULL,
  metadata = list(dataset = dataset, family = family, set = prep$set),
  init_r = e$init_r)                                            # forwarded to rstan::sampling

# A fit that returns no draws makes the diagnostic step error; record it as
# status "error" (-> "unreliable" in the summary) instead of crashing.
safe_fit <- function(...) tryCatch(fit_once(...), error = function(err)
  list(status = "error", fit = NULL, error_message = conditionMessage(err)))
a <- safe_fit(adapt_start, cfg$sampling$max_treedepth, seed)
a$escalated <- FALSE
if (identical(a$status, "refit")) {
  esc <- if (is.null(e$escalation)) cfg$sampling$escalation else e$escalation
  a <- safe_fit(esc$adapt_delta, esc$max_treedepth, seed + 1L)
  a$escalated <- TRUE
  if (identical(a$status, "refit")) a$status <- "fail"
}
if (!is.null(a$fit)) {
  a$loo <- tryCatch(brms::loo(a$fit), error = function(err) NULL)
  dr <- posterior::as_draws_df(a$fit)
  a$draws_b_sd <- tibble::as_tibble(dr[, grep("^b_|^sd_", names(dr), value = TRUE)])
}
a$condition_map <- prep$condition_map
a$K <- prep$K
qs2::qs_save(a, out_path)   # full fit kept: needed for LOO repair and PPC
cat(dataset, family, "status:", a$status, " elapsed:", round(a$elapsed_secs), "s\n")
