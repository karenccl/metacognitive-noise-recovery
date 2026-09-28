# Re-run everything downstream of the fits, in order, from the project root:
#   Rscript code/run_downstream.R
#
# Portable equivalent of `make setup compile analyse figures test` for
# machines without make (e.g. Windows). It needs data/interim/ (the 1,440
# per-fit result files); regenerate those with the grid run first
# (`Rscript code/02_fit/run_grid.R --generator g1|g0|g2`, ~26 h) or obtain
# them separately. Stops at the first failing step.

steps <- c(
  "code/00_setup/00_packages.R",
  "code/00_setup/01_config.R",
  "code/03_recovery_analysis/compile_results.R",
  "code/03_recovery_analysis/compute_primary_metrics.R",
  "code/04_ppc_and_comparison/loo_comparison.R",
  "code/04_ppc_and_comparison/diagnostics_summary.R",
  "code/04_ppc_and_comparison/ppc_joint_counts.R",
  "code/03_recovery_analysis/bias_diagnostics.R",
  "code/03_recovery_analysis/prior_summary.R",
  "code/05_figures/fig_1_design.R",
  "code/05_figures/fig_2_g0_validation.R",
  "code/05_figures/fig_3_g1_ordinal_recovery.R",
  "code/05_figures/fig_4_g2_misspecification.R",
  "code/05_figures/fig_5_ppc.R"
)

if (!file.exists("config/design.yml")) stop("Run from the project root.", call. = FALSE)
if (length(list.files("data/interim", pattern = "\\.qs2$")) == 0) {
  stop("data/interim/ has no .qs2 fit files; run the grid first (see header).", call. = FALSE)
}

rscript <- file.path(R.home("bin"), "Rscript")
for (s in steps) {
  cat(sprintf("\n=== %s ===\n", s))
  status <- system2(rscript, s)
  if (!identical(status, 0L)) stop(sprintf("Step failed: %s (exit %s)", s, status), call. = FALSE)
}

cat("\n=== unit tests ===\n")
res <- as.data.frame(testthat::test_dir("tests", reporter = "silent", stop_on_failure = FALSE))
if (sum(res$failed) > 0 || any(res$error)) stop("Unit tests failed.", call. = FALSE)
cat(sprintf("Tests: %d passed, 0 failed.\nDownstream pipeline finished.\n", sum(res$passed)))
