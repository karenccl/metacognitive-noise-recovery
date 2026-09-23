# fit_one_hmetad(): the single wrapper used everywhere hmetad::fit_metad()
# is called (protocol section 4.2). Validates input columns/category
# count, aggregates explicitly via hmetad::aggregate_metad() (see the
# "aggregation route" note below -- a deliberate refinement of the
# earlier aggregate=TRUE plan), builds a hierarchical formula and
# generator/distribution-specific priors, fits the given sampling
# configuration, and saves fit, input metadata, elapsed time, seed,
# warnings, and diagnostic summary. Returns a compact standardised
# record whether the fit succeeds or fails.
#
# Depends on: hmetad, brms, withr, dplyr, here (via callers), and
# code/02_fit/extract_fit_summary.R being loaded for extract_fit_summary().
#
# --- Aggregation route (refines docs/design_decisions.md's earlier note) ---
# fit_metad(..., aggregate = TRUE)'s own "..." dots are ambiguous: passing
# a grouping column name is not reliably distinguishable from a brm()
# sampler argument, and empirically, declaring explicit formulas for
# dpars other than the primary one (dprime, c, or the metac2_parameters
# gaps) silently changes how their prior *classes* are registered (see
# below). This wrapper therefore calls `aggregate_metad(data, <group>, K)`
# itself and passes the pre-aggregated data to fit_metad(aggregate = FALSE, ...),
# which is explicitly documented as supported ("For some models, it may
# often be easier to use the more explicit version").
#
# --- Prior class gotcha (verified empirically, not documented) ---
# When a dpar (dprime, c, or a metac2_parameters() gap) has NO explicit
# formula in bf(...) (left at the family's implicit default), its
# Intercept prior is set with `class = "<dpar_name>"` (bare, no `dpar=`
# argument -- an hmetad-specific convention). As soon as that same dpar
# is given an EXPLICIT formula (to add e.g. participant-level random
# effects), brms switches to registering it as an ordinary distributional
# parameter, and the correct prior spec becomes
# `class = "Intercept", dpar = "<dpar_name>"` instead. Passing the wrong
# form for a given formula raises "priors do not correspond to any model
# parameter". `.build_metad_priors()` below always uses the
# `dpar = "<dpar_name>"` form because this wrapper always gives every
# dpar an explicit formula (see `.build_metad_formula()`).

.build_metad_formula <- function(K, group = "participant",
                                  hierarchical_dprime_c = TRUE,
                                  hierarchical_thresholds = FALSE) {
  gap_params <- hmetad::metac2_parameters(K)
  gap_rhs <- paste(gap_params, collapse = " + ")

  mu_form <- stats::as.formula(paste0("N ~ 1 + (1|", group, ")"))
  dprime_c_rhs <- if (hierarchical_dprime_c) paste0("1 + (1|", group, ")") else "1"
  dprime_c_form <- stats::as.formula(paste0("dprime + c ~ ", dprime_c_rhs))
  thresholds_rhs <- if (hierarchical_thresholds) paste0("1 + (1|", group, ")") else "1"
  thresholds_form <- stats::as.formula(paste0(gap_rhs, " ~ ", thresholds_rhs))

  brms::bf(mu_form, dprime_c_form, thresholds_form)
}

.build_metad_priors <- function(K, log_M_prior, metac2_prior) {
  gap_params <- hmetad::metac2_parameters(K)
  gap_priors <- Reduce(`c`, lapply(
    gap_params,
    function(p) brms::set_prior(metac2_prior, class = "Intercept", dpar = p)
  ))
  gap_priors + brms::set_prior(log_M_prior, class = "Intercept")
}

.validate_metad_input <- function(data, k, group) {
  required_cols <- c(group, "stimulus", "response", "confidence")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("fit_one_hmetad: missing required column(s): ", paste(missing_cols, collapse = ", "))
  }
  if (!all(data$stimulus %in% c(0L, 1L))) stop("fit_one_hmetad: `stimulus` must be coded 0/1.")
  if (!all(data$response %in% c(0L, 1L))) stop("fit_one_hmetad: `response` must be coded 0/1.")
  if (!all(data$confidence %in% seq_len(k))) {
    stop("fit_one_hmetad: `confidence` must be coded 1:K with K = ", k, ".")
  }
  invisible(TRUE)
}

fit_one_hmetad <- function(data,
                            K = 4,
                            group = "participant",
                            distribution = "normal",
                            metac_absolute = TRUE,
                            hierarchical_dprime_c = TRUE,
                            hierarchical_thresholds = FALSE,
                            log_M_prior = "normal(0, 1)",
                            metac2_prior = "normal(0, 1)",
                            chains = 4,
                            cores = chains,
                            warmup = 1000,
                            iter_sampling = 1000,
                            adapt_delta = 0.95,
                            max_treedepth = 12,
                            rhat_max = 1.01,
                            bulk_ess_min = 400,
                            tail_ess_min = 400,
                            seed,
                            extra_stanvars = NULL,
                            metadata = list(),
                            ...) {
  .validate_metad_input(data, k = K, group = group)

  formula <- .build_metad_formula(
    K, group = group,
    hierarchical_dprime_c = hierarchical_dprime_c,
    hierarchical_thresholds = hierarchical_thresholds
  )
  priors <- .build_metad_priors(K, log_M_prior = log_M_prior, metac2_prior = metac2_prior)
  agg <- hmetad::aggregate_metad(data, !!rlang::sym(group), K = K)

  t0 <- Sys.time()
  warnings_caught <- character(0)
  fit <- tryCatch({
    withCallingHandlers(
      {
        hmetad::fit_metad(
          formula, agg,
          aggregate = FALSE, K = K,
          distribution = distribution, metac_absolute = metac_absolute,
          prior = priors, stanvars = extra_stanvars,
          chains = chains, cores = cores, iter = warmup + iter_sampling, warmup = warmup,
          control = list(adapt_delta = adapt_delta, max_treedepth = max_treedepth),
          seed = seed, refresh = 0, ...
        )
      },
      warning = function(w) {
        warnings_caught[[length(warnings_caught) + 1]] <<- conditionMessage(w)
        invokeRestart("muffleWarning")
      }
    )
  }, error = function(e) e)
  elapsed <- as.numeric(Sys.time() - t0, units = "secs")

  base_record <- c(
    metadata,
    list(
      k = K, distribution = distribution, metac_absolute = metac_absolute,
      hierarchical_dprime_c = hierarchical_dprime_c,
      hierarchical_thresholds = hierarchical_thresholds,
      n_units = nrow(agg), seed = seed, elapsed_secs = elapsed
    )
  )

  if (inherits(fit, "error")) {
    return(c(base_record, list(
      status = "error", fit = NULL, warnings = warnings_caught,
      error_message = conditionMessage(fit)
    )))
  }

  diagnostics <- extract_fit_summary(
    fit,
    rhat_max = rhat_max, bulk_ess_min = bulk_ess_min, tail_ess_min = tail_ess_min,
    max_treedepth = max_treedepth
  )
  c(base_record, list(
    status = diagnostics$status, fit = fit, warnings = warnings_caught,
    error_message = NA_character_, diagnostics = diagnostics
  ))
}
