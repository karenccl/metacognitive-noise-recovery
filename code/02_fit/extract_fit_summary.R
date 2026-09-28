# Extract standardised diagnostics from a fitted hmetad/brms model:
# max rank-normalised R-hat, min bulk/tail ESS for focal population
# parameters (population-level "b_*" effects and random-effect SDs
# "sd_*" -- not the per-subject "r_*" deviations), divergence count,
# max-treedepth hit count, and a pass/refit classification (protocol
# section 4.4). Does NOT decide "fail" -- that is the caller's
# escalation-policy decision after a refit attempt (run_one_cell.R,
# not yet implemented), since a single call can't know its own retry
# history. Pareto k / LOO diagnostics are out of scope here (only
# relevant for G2's LOO comparison, added in code/04_ppc_and_comparison/).

extract_fit_summary <- function(fit,
                                 rhat_max = 1.01,
                                 bulk_ess_min = 400,
                                 tail_ess_min = 400,
                                 max_treedepth = NULL) {
  draws <- posterior::as_draws_array(fit)
  all_vars <- posterior::variables(draws)
  focal_vars <- grep("^b_|^sd_", all_vars, value = TRUE)
  if (length(focal_vars) == 0) focal_vars <- all_vars

  summ <- posterior::summarise_draws(
    draws[, , focal_vars, drop = FALSE], "rhat", "ess_bulk", "ess_tail"
  )

  nuts <- tryCatch(brms::nuts_params(fit), error = function(e) NULL)
  n_divergent <- if (!is.null(nuts)) {
    sum(nuts$Value[nuts$Parameter == "divergent__"])
  } else {
    NA_integer_
  }
  treedepth_vals <- if (!is.null(nuts)) nuts$Value[nuts$Parameter == "treedepth__"] else NA_real_
  max_treedepth_used <- if (!is.null(nuts)) max(treedepth_vals) else NA_real_
  n_at_max_treedepth <- if (!is.null(nuts) && !is.null(max_treedepth)) {
    sum(treedepth_vals >= max_treedepth)
  } else {
    NA_integer_
  }

  max_rhat <- suppressWarnings(max(summ$rhat, na.rm = TRUE))
  min_ess_bulk <- suppressWarnings(min(summ$ess_bulk, na.rm = TRUE))
  min_ess_tail <- suppressWarnings(min(summ$ess_tail, na.rm = TRUE))

  flags <- character(0)
  if (!is.finite(max_rhat) || max_rhat > rhat_max) flags <- c(flags, "rhat")
  if (!is.na(n_divergent) && n_divergent > 0) flags <- c(flags, "divergences")
  if (!is.finite(min_ess_bulk) || min_ess_bulk < bulk_ess_min) flags <- c(flags, "bulk_ess")
  if (!is.finite(min_ess_tail) || min_ess_tail < tail_ess_min) flags <- c(flags, "tail_ess")
  if (!is.na(n_at_max_treedepth) && n_at_max_treedepth > 0) flags <- c(flags, "max_treedepth")

  status <- if (length(flags) == 0) "pass" else "refit"

  list(
    status = status,
    flags = flags,
    max_rhat = max_rhat,
    min_ess_bulk = min_ess_bulk,
    min_ess_tail = min_ess_tail,
    n_divergent = n_divergent,
    max_treedepth_used = max_treedepth_used,
    n_at_max_treedepth = n_at_max_treedepth,
    focal_params = focal_vars,
    param_summary = summ
  )
}
