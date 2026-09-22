# Install and load required packages; set brms/cmdstanr backend.
# Run once per environment. See docs/computational_environment.md for
# the versions this project was verified against.
#
# Note: the protocol's original package list names "qs" for atomic
# result storage, but qs is archived on CRAN for current R. Use qs2
# (same author, maintained successor) instead: qs2::qs_save() /
# qs2::qs_read(), with a .qs2 extension on interim files.

# renv::init()
# install.packages(c(
#   "hmetad", "brms", "cmdstanr", "posterior", "bayesplot",
#   "loo", "tidyverse", "tidybayes", "yaml", "here", "qs2",
#   "testthat", "devtools"
# ))
#
# options(brms.backend = "cmdstanr")
# stopifnot(!is.null(cmdstanr::cmdstan_version()))
# renv::snapshot()
