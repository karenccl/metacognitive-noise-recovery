# v3 step 2a: exact refits (reloo) for participants with Pareto k > 0.7 on
# the 48 stored G2 full fits (rep_id 1-2; docs/v3_plan.md §3). A reloo refit
# leaves one PARTICIPANT out (the LOO unit of these aggregated-count models,
# see loo_comparison.R) and predicts it as a new level: brms's reloo sets
# allow_new_levels = TRUE itself (sample_new_levels = "gaussian"; API check
# logged 2026-09-29). Other participants keep their PSIS values.
#
# Resumable and shardable:
#   Rscript code/04_ppc_and_comparison/v3_reloo_stored_fits.R <shard> <n_shards>
# e.g. run "1 3", "2 3", "3 3" in three terminals (each uses 4 cores).

suppressPackageStartupMessages({ library(dplyr); library(brms); library(hmetad) })
# gumbel_min fits: R-side lcdf/lccdf must exist for log_lik() and epred.
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))

args     <- commandArgs(trailingOnly = TRUE)
shard    <- if (length(args) >= 1) as.integer(args[1]) else 1L
n_shards <- if (length(args) >= 2) as.integer(args[2]) else 1L
cfg3     <- yaml::read_yaml(here::here("config", "v3.yml"))
k_thr    <- cfg3$loo_robust$k_threshold
# Sampler cores for the refits come from mc.cores (brm's default). Do NOT pass
# `cores` in reloo_args: reloo forwards it to log_lik() as well, which then
# runs on a PSOCK cluster whose workers lack gumbel_min_lcdf (Windows).
options(mc.cores = 4)

out_dir <- here::here("data", "interim", "v3_reloo")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

files <- sort(list.files(here::here("data", "interim"),
                         pattern = "^g2_.*_rep-0[12]_.*[.]qs2$", full.names = TRUE))
stopifnot(length(files) == 48)
files <- files[(seq_along(files) - 1L) %% n_shards == (shard - 1L)]

for (f in files) {
  out_path <- file.path(out_dir, basename(f))
  if (file.exists(out_path)) { cat("skip", basename(f), "\n"); next }

  r <- qs2::qs_read(f)
  stopifnot(inherits(r$fit, "brmsfit"), !is.null(r$loo))
  k     <- r$loo$diagnostics$pareto_k
  n_bad <- sum(k > k_thr)
  t0    <- Sys.time()

  loo_exact <- if (n_bad == 0) {
    r$loo
  } else {
    # Refits use the stored fit's own seed so the run is repeatable.
    tryCatch(
      brms::loo(r$fit, reloo = TRUE, k_threshold = k_thr,
                reloo_args = list(seed = r$seed)),
      error = function(e) e)
  }

  rec <- list(grid_id = r$grid_id, cell_id = r$cell_id, rep_id = r$rep_id,
              fit_variant = r$fit_variant, n_participants = r$n_participants,
              n_trials = r$n_trials, dprime_target = r$dprime_target,
              status = r$status, n_bad_k = n_bad, loo_psis = r$loo,
              loo_exact = loo_exact,
              ok = !inherits(loo_exact, "error"),
              elapsed_secs = as.numeric(difftime(Sys.time(), t0, units = "secs")))
  qs2::qs_save(rec, out_path)
  cat(sprintf("%s  n_bad=%d  ok=%s  %.0fs\n", basename(f), n_bad, rec$ok, rec$elapsed_secs))
  if (!rec$ok) cat("  error:", conditionMessage(loo_exact), "\n")
}
