# fit_one_hmetad(): the single wrapper used everywhere hmetad::fit_metad()
# is called (docs/design_decisions.md). Validates input columns/category
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

# v3 (docs/v3_plan.md §4.2): optional population-level covariates on
# dprime/c and on log_M (the mu part). With both NULL (the default) the
# formula is identical to v1.2.1 (tests/test_formula_backcompat.R).
.build_metad_formula <- function(K, group = "participant",
                                  hierarchical_dprime_c = TRUE,
                                  hierarchical_thresholds = FALSE,
                                  dprime_c_covariates = NULL,
                                  log_M_covariates = NULL) {
  gap_params <- hmetad::metac2_parameters(K)
  gap_rhs <- paste(gap_params, collapse = " + ")
  re <- paste0("(1|", group, ")")
  fixed <- function(covs) paste(c("1", covs), collapse = " + ")

  mu_form <- stats::as.formula(paste0("N ~ ", fixed(log_M_covariates), " + ", re))
  dprime_c_rhs <- if (hierarchical_dprime_c) paste0(fixed(dprime_c_covariates), " + ", re)
                  else fixed(dprime_c_covariates)
  dprime_c_form <- stats::as.formula(paste0("dprime + c ~ ", dprime_c_rhs))
  thresholds_rhs <- if (hierarchical_thresholds) paste0("1 + ", re) else "1"
  thresholds_form <- stats::as.formula(paste0(gap_rhs, " ~ ", thresholds_rhs))

  brms::bf(mu_form, dprime_c_form, thresholds_form)
}

.build_metad_priors <- function(K, log_M_prior, metac2_prior,
                                log_M_b_prior = NULL, sd_prior = NULL,
                                hierarchical_dprime_c = TRUE,
                                hierarchical_thresholds = FALSE) {
  gap_params <- hmetad::metac2_parameters(K)
  gap_priors <- Reduce(`c`, lapply(
    gap_params,
    function(p) brms::set_prior(metac2_prior, class = "Intercept", dpar = p)
  ))
  pri <- gap_priors + brms::set_prior(log_M_prior, class = "Intercept")
  # Only when log_M has covariates: prior on its condition coefficients
  # (class "b" with no dpar = the mu / log_M part of the model).
  if (!is.null(log_M_b_prior)) pri <- pri + brms::set_prior(log_M_b_prior, class = "b")
  # v3 empirical deviation (docs/analysis_log.md 2026-09-30): an explicit prior
  # on every participant-level SD instead of brms's student_t(3, 0, 2.5)
  # default. NULL (the default) leaves the v1.2.1 priors unchanged.
  if (!is.null(sd_prior)) {
    sd_dpars <- c("", if (hierarchical_dprime_c) c("dprime", "c"),
                  if (hierarchical_thresholds) gap_params)
    pri <- pri + Reduce(`c`, lapply(sd_dpars, function(p) brms::set_prior(sd_prior, class = "sd", dpar = p)))
  }
  pri
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
                            # --- v3 additions (defaults reproduce v1.2.1 exactly) ---
                            agg_by = NULL,               # extra grouping columns, e.g. "difficulty"
                            dprime_c_covariates = NULL,  # e.g. "difficulty"
                            log_M_covariates = NULL,     # e.g. "condition" (empirical only)
                            log_M_b_prior = if (is.null(log_M_covariates)) NULL else "normal(0, 1)",
                            sd_prior = NULL,             # prior on all participant-level SDs
                            # ---------------------------------------------------------
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
  if (!is.null(agg_by)) {
    miss <- setdiff(agg_by, names(data))
    if (length(miss)) stop("fit_one_hmetad: agg_by column(s) not in data: ", paste(miss, collapse = ", "))
  }
  if (!all(c(dprime_c_covariates, log_M_covariates) %in% agg_by)) {
    stop("fit_one_hmetad: every covariate must also be listed in agg_by")
  }

  formula <- .build_metad_formula(
    K, group = group,
    hierarchical_dprime_c = hierarchical_dprime_c,
    hierarchical_thresholds = hierarchical_thresholds,
    dprime_c_covariates = dprime_c_covariates,
    log_M_covariates = log_M_covariates
  )
  priors <- .build_metad_priors(K, log_M_prior = log_M_prior, metac2_prior = metac2_prior,
                                log_M_b_prior = log_M_b_prior, sd_prior = sd_prior,
                                hierarchical_dprime_c = hierarchical_dprime_c,
                                hierarchical_thresholds = hierarchical_thresholds)
  agg <- hmetad::aggregate_metad(data, !!!rlang::syms(c(group, agg_by)), K = K)

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
          # Pinned: all production fits used brms's default rstan backend; a
          # global options(brms.backend = "cmdstanr") would otherwise switch
          # samplers silently and break bit-for-bit reproduction.
          backend = "rstan",
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
      agg_by = agg_by, dprime_c_covariates = dprime_c_covariates,
      log_M_covariates = log_M_covariates, sd_prior = sd_prior,
      n_units = nrow(agg), seed = seed, elapsed_secs = elapsed, agg = agg
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
