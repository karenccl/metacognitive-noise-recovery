# fit_one_hmetad(): the single wrapper used everywhere fit_metad() is
# called (protocol section 4.2). Validates input columns/category
# count, aggregates via aggregate_metad() (or documents the package's
# auto-aggregation route), applies generator/distribution-specific
# priors, fits the locked sampling configuration, and saves fit, input
# metadata, elapsed time, seed, warnings, and diagnostic summary.
# Returns a compact standardised record whether the fit succeeds or
# fails.

fit_one_hmetad <- function(data, distribution = "gaussian", priors = NULL, ...) {
  stop("not yet implemented")
}
