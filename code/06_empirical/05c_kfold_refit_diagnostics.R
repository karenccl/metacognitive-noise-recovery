# Diagnose EVERY grouped K-fold refit (review response, 2026-10-15).
# 05_loo_repair.R ran brms::kfold() with save_fits = FALSE, so only the pilot
# dataset (05a_kfold_pilot.R) had refit diagnostics. This script reruns the
# identical K-fold step (same folds, seeds, sampler settings via
# loo_repair_functions.R) with save_fits = TRUE for every dataset whose stored
# repair used K-fold, applies the same diagnostic rule as the full-data fits
# (extract_fit_summary(): R-hat <= 1.01, bulk/tail ESS >= 400 for b_/sd_
# parameters, no divergences, no max-treedepth hits), checks that the
# recomputed ELPD reproduces the stored one, and drops the refits.
#
# Resumable and shardable by dataset (memory: one dataset-family holds the
# full fit plus 5 refits, ~2-3 GB; 2-3 shards on a 32 GB machine):
#   Rscript code/06_empirical/05c_kfold_refit_diagnostics.R <shard> <n_shards>
#   Rscript code/06_empirical/05c_kfold_refit_diagnostics.R --summarise
# Outputs:
#   data/interim/v3_empirical/kfold_diag/<dataset>__<family>.csv  (per fold)
#   data/processed/v3/empirical/kfold_refit_diagnostics.csv          (all folds)
#   data/processed/v3/empirical/kfold_refit_by_dataset.csv           (per dataset)

suppressPackageStartupMessages({ library(dplyr); library(brms); library(hmetad) })
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "02_fit", "extract_fit_summary.R"))
source(here::here("code", "06_empirical", "loo_repair_functions.R"))
options(mc.cores = 4, future.globals.maxSize = Inf)   # as in 05_loo_repair.R
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml")); e <- cfg3$empirical
cfg  <- yaml::read_yaml(here::here("config", "design.yml"))

fams     <- c("normal", "gumbel_min")
fit_dir  <- here::here("data", "interim", "v3_empirical", "fits")
rep_dir  <- here::here("data", "interim", "v3_empirical", "loo_repaired")
diag_dir <- here::here("data", "interim", "v3_empirical", "kfold_diag")
proc_dir <- here::here("data", "processed", "v3", "empirical")
dir.create(diag_dir, recursive = TRUE, showWarnings = FALSE)

by_ds    <- readr::read_csv(file.path(proc_dir, "empirical_by_dataset.csv"), show_col_types = FALSE)
datasets <- sort(by_ds$dataset[!is.na(by_ds$method) & by_ds$method == "kfold"])

args <- commandArgs(trailingOnly = TRUE)

summarise_all <- function() {
  files <- list.files(diag_dir, "[.]csv$", full.names = TRUE)
  d <- purrr::map_dfr(files, readr::read_csv, show_col_types = FALSE)
  readr::write_csv(d, file.path(proc_dir, "kfold_refit_diagnostics.csv"))
  per_ds <- d |>
    group_by(dataset) |>
    summarise(n_refits = n(),
              n_fail = sum(status != "pass"),
              n_fail_normal = sum(status != "pass" & family == "normal"),
              n_fail_gumbel = sum(status != "pass" & family == "gumbel_min"),
              n_fail_divergence_only = sum(flags == "divergences"),
              total_divergent = sum(n_divergent),
              max_rhat = max(max_rhat),
              min_ess_bulk = min(min_ess_bulk),
              min_ess_tail = min(min_ess_tail),
              elpd_reproduced = all(elpd_reproduced),
              elpd_exact = all(elpd_exact),
              max_elpd_absdiff = max(elpd_absdiff),
              .groups = "drop") |>
    left_join(select(by_ds, dataset, set, category, elpd_diff, se), by = "dataset") |>
    mutate(cv_refits_pass = n_fail == 0,
           category_cv_diag = ifelse(cv_refits_pass, category, "unreliable"))
  readr::write_csv(per_ds, file.path(proc_dir, "kfold_refit_by_dataset.csv"))
  cat(sprintf("%d datasets, %d refits; %d refits failed; %d datasets with all refits passing\n",
              nrow(per_ds), nrow(d), sum(d$status != "pass"), sum(per_ds$cv_refits_pass)))
  print(as.data.frame(select(per_ds, dataset, set, category, n_fail, n_fail_normal,
                             n_fail_gumbel, total_divergent, max_rhat, elpd_reproduced,
                             elpd_exact, max_elpd_absdiff,
                             category_cv_diag)))
  missing <- setdiff(datasets, unique(d$dataset))
  if (length(missing)) cat("Not yet run:", paste(missing, collapse = ", "), "\n")
}

if ("--summarise" %in% args) { summarise_all(); quit(save = "no") }

shard    <- if (length(args) >= 1) as.integer(args[1]) else 1L
n_shards <- if (length(args) >= 2) as.integer(args[2]) else 1L
mine     <- datasets[(seq_along(datasets) - 1L) %% n_shards == (shard - 1L)]

for (ds in mine) {
  outs <- file.path(diag_dir, sprintf("%s__%s.csv", ds, fams))
  if (all(file.exists(outs))) next
  fits  <- purrr::map(file.path(fit_dir, sprintf("%s__%s.qs2", ds, fams)), qs2::qs_read)
  folds <- make_folds(fits, ds, cfg3)          # identical folds to 05_loo_repair.R
  for (j in 1:2) {
    if (file.exists(outs[j])) next
    f  <- fits[[j]]; t0 <- Sys.time(); ra <- refit_args(f, e, cfg)
    kf <- do.call(brms::kfold, c(list(f$fit, folds = folds, save_fits = TRUE), ra))
    stored <- qs2::qs_read(file.path(rep_dir, sprintf("%s__%s.qs2", ds, fams[j])))
    elpd_new    <- kf$estimates["elpd_kfold", "Estimate"]
    elpd_stored <- stored$loo_repaired$estimates["elpd_kfold", "Estimate"]
    se_stored   <- stored$loo_repaired$estimates["elpd_kfold", "SE"]
    # The refits are seeded (same Stan draws), but the held-out participant's
    # effects (sample_new_levels = "gaussian") are drawn with R's RNG, seeded once
    # per dataset in make_folds(); if the original run was resumed between the two
    # families, the second family's draws differ slightly. So "reproduced" means a
    # difference below 1% of the stored SE; exact agreement is recorded separately.
    elpd_absdiff <- abs(elpd_new - elpd_stored)
    tab <- purrr::map_dfr(seq_len(nrow(kf$fits)), function(k) {
      m <- kf$fits[k, "fit"][[1]]
      s <- extract_fit_summary(m, max_treedepth = ra$control$max_treedepth)
      tibble::tibble(dataset = ds, family = fams[j], fold = k,
                     adapt_delta = ra$control$adapt_delta,
                     max_treedepth = ra$control$max_treedepth,
                     status = s$status, flags = paste(s$flags, collapse = ";"),
                     max_rhat = s$max_rhat, min_ess_bulk = s$min_ess_bulk,
                     min_ess_tail = s$min_ess_tail, n_divergent = s$n_divergent,
                     n_at_max_treedepth = s$n_at_max_treedepth,
                     elpd_kfold = elpd_new, elpd_kfold_stored = elpd_stored,
                     elpd_se_stored = se_stored, elpd_absdiff = elpd_absdiff,
                     elpd_exact = isTRUE(elpd_absdiff < 1e-6),
                     elpd_reproduced = isTRUE(elpd_absdiff < 0.01 * se_stored),
                     elapsed_secs = as.numeric(difftime(Sys.time(), t0, units = "secs")))
    })
    readr::write_csv(tab, outs[j])
    cat(ds, fams[j], sprintf("failed refits %d/%d; ELPD reproduced: %s (|diff| %.2g, exact: %s)\n",
                             sum(tab$status != "pass"), nrow(tab), tab$elpd_reproduced[1],
                             elpd_absdiff, tab$elpd_exact[1]))
    kf$fits <- NULL; rm(kf); gc()
  }
  rm(fits); gc()
}
