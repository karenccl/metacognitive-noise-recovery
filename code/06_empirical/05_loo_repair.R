# v3 empirical step 5.8 (docs/v3_plan.md): repair PSIS-LOO for each dataset.
# If both families have a bad-k share <= loo_repair$max_prop_bad_k_for_reloo:
# reloo (exact refits for k > 0.7 rows); otherwise grouped K-fold by
# participant with folds shared by both families. The two families of a
# dataset always use the same method (reloo and K-fold values are not comparable).
# Resumable and shardable by dataset:
#   Rscript code/06_empirical/05_loo_repair.R <shard> <n_shards>

suppressPackageStartupMessages({ library(dplyr); library(brms); library(hmetad) })
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
# Sampler cores via mc.cores; passing `cores` to reloo/kfold would also send it
# to log_lik(), whose PSOCK workers lack gumbel_min_lcdf (see v3_reloo_stored_fits.R).
options(mc.cores = 4)
args     <- commandArgs(trailingOnly = TRUE)
shard    <- if (length(args) >= 1) as.integer(args[1]) else 1L
n_shards <- if (length(args) >= 2) as.integer(args[2]) else 1L
cfg3  <- yaml::read_yaml(here::here("config", "v3.yml")); e <- cfg3$empirical
k_thr <- cfg3$loo_robust$k_threshold
fit_dir <- here::here("data", "interim", "v3_empirical", "fits")
rep_dir <- here::here("data", "interim", "v3_empirical", "loo_repaired")
dir.create(rep_dir, recursive = TRUE, showWarnings = FALSE)

fams <- c("normal", "gumbel_min")
datasets <- sort(unique(sub("__.*$", "", list.files(fit_dir, "[.]qs2$"))))
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
  prop_bad <- purrr::map_dbl(fits, ~ mean(.x$loo$diagnostics$pareto_k > k_thr))
  method <- if (all(prop_bad <= e$loo_repair$max_prop_bad_k_for_reloo)) "reloo" else "kfold"

  if (method == "kfold") {
    # One fold per participant (all of a participant's rows together), shared across families.
    part <- fits[[1]]$fit$data$participant
    stopifnot(identical(part, fits[[2]]$fit$data$participant))
    set.seed(cfg3$seed_base_v3 + sum(utf8ToInt(ds)))
    pf <- loo::kfold_split_random(K = cfg3$loo_robust$kfold_K, N = length(unique(part)))
    folds <- pf[match(part, sort(unique(part)))]
  }
  for (j in 1:2) {
    if (file.exists(outs[j])) next
    f <- fits[[j]]; t0 <- Sys.time()
    res <- if (method == "reloo") {
      tryCatch(brms::loo(f$fit, reloo = TRUE, k_threshold = k_thr,
                         reloo_args = list(seed = f$seed)),
               error = function(err) err)
    } else {
      tryCatch(brms::kfold(f$fit, folds = folds, seed = f$seed, save_fits = FALSE),
               error = function(err) err)
    }
    qs2::qs_save(list(dataset = ds, family = fams[j], method = method,
                      prop_bad_k = prop_bad[j], loo_repaired = res,
                      ok = !inherits(res, "error"),
                      elapsed_secs = as.numeric(difftime(Sys.time(), t0, units = "secs"))), outs[j])
    cat(ds, fams[j], method, sprintf("prop_bad=%.3f", prop_bad[j]), "ok:", !inherits(res, "error"), "\n")
    if (inherits(res, "error")) cat("  error:", conditionMessage(res), "\n")
  }
}
