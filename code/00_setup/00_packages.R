# Check that the packages the pipeline needs are installed (run by
# `make setup`). It does not install anything: restore the pinned
# environment with `renv::restore()` (see README and
# docs/computational_environment.md).
#
# Backend note (corrected 2026-09-25): brms.backend was never set, so every
# production fit used brms's default rstan backend, not cmdstanr. Do NOT set
# options(brms.backend = "cmdstanr") if you want to reproduce the published
# results. The original protocol plan named "qs"; it is archived on CRAN, so
# qs2 is used instead.

required <- c(
  "hmetad", "brms", "rstan", "StanHeaders", "posterior", "loo", "dplyr", "tidyr",
  "purrr", "tibble", "readr", "ggplot2", "gridExtra", "yaml", "here", "qs2",
  "processx", "testthat"
)
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Missing packages: ", paste(missing, collapse = ", "),
       ". Run renv::restore() from the project root.", call. = FALSE)
}
ver <- vapply(required, function(p) as.character(utils::packageVersion(p)), "")
cat("R", format(getRversion()), "- all", length(required), "required packages present:\n")
print(data.frame(package = required, version = unname(ver)), row.names = FALSE)
cat("brms backend option:", getOption("brms.backend", default = "(unset -> rstan)"), "\n")
