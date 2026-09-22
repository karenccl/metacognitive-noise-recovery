# Install and load required packages; set brms/cmdstanr backend.
# Run once per environment. See docs/computational_environment.md for
# the versions this project was verified against.

# renv::init()
# install.packages(c(
#   "hmetad", "brms", "cmdstanr", "posterior", "bayesplot",
#   "loo", "tidyverse", "tidybayes", "yaml", "here", "qs",
#   "testthat", "devtools"
# ))
#
# options(brms.backend = "cmdstanr")
# stopifnot(!is.null(cmdstanr::cmdstan_version()))
# renv::snapshot()
