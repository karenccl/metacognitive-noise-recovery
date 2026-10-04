# Pilot for the grouped K-fold LOO repair (docs/analysis_log.md 2026-10-04):
# run 05_loo_repair.R's exact K-fold step on ONE dataset with save_fits = TRUE,
# so the convergence of every fold refit can be checked (the production run uses
# save_fits = FALSE and keeps no refit diagnostics). Run ALONE, before the
# production shards.
#
# Writes: data/processed/v3/empirical/kfold_pilot_diagnostics.csv (one row per
# family x fold) and the two repair records in loo_repaired/ in the production
# format (same folds, seeds and settings; refits dropped), so the production run
# skips this dataset. The refits themselves (~3 GB) are not kept.
# Stop and report if refits diverge heavily: do not start the production run.
#
# Usage: Rscript code/06_empirical/05a_kfold_pilot.R [dataset]   (default Gherman_2018)

suppressPackageStartupMessages({ library(dplyr); library(brms); library(hmetad) })
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "06_empirical", "loo_repair_functions.R"))
options(mc.cores = 4, future.globals.maxSize = Inf)   # as in 05_loo_repair.R
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml")); e <- cfg3$empirical
cfg  <- yaml::read_yaml(here::here("config", "design.yml"))
args <- commandArgs(trailingOnly = TRUE)
ds   <- if (length(args) >= 1) args[1] else "Gherman_2018"

fams <- c("normal", "gumbel_min")
fit_dir <- here::here("data", "interim", "v3_empirical", "fits")
rep_dir <- here::here("data", "interim", "v3_empirical", "loo_repaired")
dir.create(rep_dir, recursive = TRUE, showWarnings = FALSE)
fits <- purrr::map(file.path(fit_dir, sprintf("%s__%s.qs2", ds, fams)), qs2::qs_read)
rm_ <- repair_method(fits, e, cfg3)
stopifnot(rm_$method == "kfold")
folds <- make_folds(fits, ds, cfg3)

diag <- purrr::map_dfr(1:2, function(j) {
  f <- fits[[j]]; t0 <- Sys.time(); ra <- refit_args(f, e, cfg)
  kf <- do.call(brms::kfold, c(list(f$fit, folds = folds, save_fits = TRUE), ra))
  tab <- purrr::map_dfr(seq_len(nrow(kf$fits)), function(k) {
    m <- kf$fits[k, "fit"][[1]]
    tibble::tibble(dataset = ds, family = fams[j], fold = k,
                   adapt_delta = m$fit@stan_args[[1]]$control$adapt_delta,
                   max_treedepth = m$fit@stan_args[[1]]$control$max_treedepth,
                   iter = m$fit@sim$iter, warmup = m$fit@sim$warmup, chains = m$fit@sim$chains,
                   divergent = sum(rstan::get_divergent_iterations(m$fit)),
                   max_rhat = max(brms::rhat(m), na.rm = TRUE),
                   min_ess_bulk = min(posterior::summarise_draws(m, "ess_bulk")$ess_bulk, na.rm = TRUE))
  })
  kf$fits <- NULL                                    # drop the ~1.5 GB of refits
  qs2::qs_save(repair_record(ds, fams[j], "kfold", rm_$prop_bad[j], kf, t0),
               file.path(rep_dir, sprintf("%s__%s.qs2", ds, fams[j])))
  rm(kf); gc()
  tab
})
out <- here::here("data", "processed", "v3", "empirical", "kfold_pilot_diagnostics.csv")
readr::write_csv(diag, out)
print(as.data.frame(diag), digits = 4)
cat(sprintf("\nTotal divergent transitions: %d over %d refits; max R-hat %.3f\n",
            sum(diag$divergent), nrow(diag), max(diag$max_rhat)))
