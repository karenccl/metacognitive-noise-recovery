# v3 empirical step 5.8 (docs/v3_plan.md): repair PSIS-LOO for each dataset.
# If both families have a bad-k share <= loo_repair$max_prop_bad_k_for_reloo:
# reloo (exact refits for k > 0.7 rows); otherwise grouped K-fold by
# participant with folds shared by both families. The two families of a
# dataset always use the same method (reloo and K-fold values are not comparable).
# Resumable and shardable by dataset:
#   Rscript code/06_empirical/05_loo_repair.R <shard> <n_shards> [--include-tier3]
# Run 05b_loo_tiers.R first.
# Run with 4 shards (memory: each shard holds both fits of a dataset, 1-1.7 GB,
# plus the refit in progress; 5 shards left < 5 GB of 31 GB free).

suppressPackageStartupMessages({ library(dplyr); library(brms); library(hmetad) })
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "06_empirical", "loo_repair_functions.R"))
# Sampler cores via mc.cores; passing `cores` to reloo/kfold would also send it
# to log_lik(), whose PSOCK workers lack gumbel_min_lcdf (see v3_reloo_stored_fits.R).
options(mc.cores = 4)
# kfold()/reloo() pass the brmsfit through future.apply; these fits are 0.5-1 GB,
# above future's default 500 MB export limit. The plan is sequential (in-process),
# so nothing is copied; lift the limit.
options(future.globals.maxSize = Inf)
args     <- commandArgs(trailingOnly = TRUE)
shard    <- if (length(args) >= 1) as.integer(args[1]) else 1L
n_shards <- if (length(args) >= 2) as.integer(args[2]) else 1L
include_tier3 <- "--include-tier3" %in% args
cfg3  <- yaml::read_yaml(here::here("config", "v3.yml")); e <- cfg3$empirical
cfg   <- yaml::read_yaml(here::here("config", "design.yml"))
k_thr <- cfg3$loo_robust$k_threshold
fit_dir <- here::here("data", "interim", "v3_empirical", "fits")
rep_dir <- here::here("data", "interim", "v3_empirical", "loo_repaired")
dir.create(rep_dir, recursive = TRUE, showWarnings = FALSE)

fams <- c("normal", "gumbel_min")
datasets <- sort(unique(sub("__.*$", "", list.files(fit_dir, "[.]qs2$"))))
# Execution order only (results do not depend on it: folds and seeds are fixed
# per dataset). By tier (05b_loo_tiers.R -> loo_repair_tiers.csv: 1 both fits
# pass, 2 divergence-only, 3 unreliable under both pre-specified rules), then
# set (primary first), then name. Tier 3 runs only with --include-tier3: no
# pre-specified category depends on tier-3 LOO.
set_order <- c("primary", "sensitivity", "sensitivity_unrecorded", "secondary")
tiers <- readr::read_csv(here::here("data", "processed", "v3", "empirical", "loo_repair_tiers.csv"),
                         show_col_types = FALSE)
stopifnot(setequal(tiers$dataset, datasets))
tiers <- tiers[order(tiers$tier, match(tiers$set, set_order), tiers$dataset), ]
if (!include_tier3) tiers <- tiers[tiers$tier < 3, ]
datasets <- tiers$dataset
datasets <- datasets[(seq_along(datasets) - 1L) %% n_shards == (shard - 1L)]

for (ds in datasets) {
  paths <- file.path(fit_dir, sprintf("%s__%s.qs2", ds, fams))
  outs  <- file.path(rep_dir, sprintf("%s__%s.qs2", ds, fams))
  if (!all(file.exists(paths))) { cat(ds, ": both families not fitted yet, skipping\n"); next }
  if (all(file.exists(outs))) next
  fits <- purrr::map(paths, qs2::qs_read)
  if (any(purrr::map_lgl(fits, ~ is.null(.x$fit) || is.null(.x$loo)))) {
    for (j in 1:2) qs2::qs_save(list(dataset = ds, family = fams[j], method = NA_character_,
                                     prop_bad_k = NA_real_, loo_repaired = NULL, ok = FALSE), outs[j])
    cat(ds, ": a fit or its loo is missing; recorded as not repaired\n"); next
  }
  rm_ <- repair_method(fits, e, cfg3); prop_bad <- rm_$prop_bad; method <- rm_$method
  if (method == "kfold") folds <- make_folds(fits, ds, cfg3)
  for (j in 1:2) {
    if (file.exists(outs[j])) next
    f <- fits[[j]]; t0 <- Sys.time()
    res <- if (method == "reloo") {
      tryCatch(brms::loo(f$fit, reloo = TRUE, k_threshold = k_thr, reloo_args = refit_args(f, e, cfg)),
               error = function(err) err)
    } else {
      tryCatch(do.call(brms::kfold, c(list(f$fit, folds = folds, save_fits = FALSE), refit_args(f, e, cfg))),
               error = function(err) err)
    }
    qs2::qs_save(repair_record(ds, fams[j], method, prop_bad[j], res, t0), outs[j])
    cat(ds, fams[j], method, sprintf("prop_bad=%.3f", prop_bad[j]), "ok:", !inherits(res, "error"), "\n")
    if (inherits(res, "error")) cat("  error:", conditionMessage(res), "\n")
  }
}
