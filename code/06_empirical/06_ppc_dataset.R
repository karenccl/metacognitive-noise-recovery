# v3 empirical step 5.9 (docs/v3_plan.md): replicated-data posterior predictive
# p-values (ppp_functions.R, any K, grouped by every aggregation column) for
# every empirical fit, on 1000 posterior draws.
#
# Run from the project root: Rscript code/06_empirical/06_ppc_dataset.R

suppressPackageStartupMessages(library(dplyr))
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "04_ppc_and_comparison", "ppp_functions.R"))
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml"))
fit_dir <- here::here("data", "interim", "v3_empirical", "fits")

files <- sort(list.files(fit_dir, "[.]qs2$", full.names = TRUE))
ppc <- purrr::map_dfr(files, function(f) {
  a <- qs2::qs_read(f)
  if (is.null(a$fit)) return(NULL)
  gcols <- setdiff(names(a$agg), c("N", "N_0", "N_1"))
  stopifnot(all(gcols %in% c("participant", "condition")))
  res <- tryCatch(ppp_one_fit_general(a$fit, a$agg, K = a$K, group_cols = gcols,
                                      seed = cfg3$seed_base_v3 + sum(utf8ToInt(basename(f))),
                                      ndraws = 1000),
                  error = function(err) { message(basename(f), ": ", conditionMessage(err)); NULL })
  if (is.null(res)) return(NULL)
  cat(sprintf("%-45s p1=%.3f p2=%.3f p3=%.3f\n", basename(f), res$p_stat1_rmse,
              res$p_stat2_highconf, res$p_stat3_x2_df))
  dplyr::bind_cols(tibble::tibble(dataset = a$dataset, family = a$family), res)
})
readr::write_csv(ppc, here::here("data", "processed", "v3", "empirical", "ppc_by_fit.csv"))
