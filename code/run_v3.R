# Re-run every v3 step that needs no refitting, in order, from the project root:
#   Rscript code/run_v3.R
#
# Portable equivalent of `make v3-relbias` + the summary halves of the other
# v3 targets + `make v3-figures test`, for machines without make (e.g. Windows).
# It needs the refit outputs already in data/interim/ (v3_reloo/, v3_g3/,
# v3_empirical/); produce those with the shard scripts listed in the Makefile.
# Stops at the first failing step.

steps <- c(
  "code/03_recovery_analysis/relative_bias.R",
  "code/04_ppc_and_comparison/v3_loo_robust_summary.R",
  "code/04_ppc_and_comparison/v3_g3_summary.R",
  "code/06_empirical/07_summarise_empirical.R",
  "code/05_figures/fig_6_relative_bias.R",
  "code/05_figures/fig_7_loo_robust.R",
  "code/05_figures/fig_8_g3_mixture.R",
  "code/05_figures/fig_9_empirical.R"
)

if (!file.exists("config/v3.yml")) stop("Run from the project root.", call. = FALSE)

rscript <- file.path(R.home("bin"), "Rscript")
for (s in steps) {
  cat(sprintf("\n=== %s ===\n", s))
  status <- system2(rscript, s)
  if (!identical(status, 0L)) stop(sprintf("Step failed: %s (exit %s)", s, status), call. = FALSE)
}

cat("\n=== unit tests ===\n")
res <- as.data.frame(testthat::test_dir("tests", reporter = "silent", stop_on_failure = FALSE))
if (sum(res$failed) > 0 || any(res$error)) stop("Unit tests failed.", call. = FALSE)
cat(sprintf("Tests: %d passed, 0 failed.\nv3 downstream pipeline finished.\n", sum(res$passed)))
