# Shared by 05_loo_repair.R and 05a_kfold_pilot.R so both use identical folds,
# refit settings and output records. Needs `e` (config/v3.yml$empirical),
# `cfg3` (config/v3.yml) and `cfg` (config/design.yml) passed in.

# Refit sampler settings, passed explicitly so they cannot depend on what
# update() carries over: the fit's own settings (escalated fits used the stricter
# escalation settings). brms 2.23's update.brmsfit already copies control,
# warmup, iter and chains from the stored fit (checked 2026-10-04); this makes
# it explicit.
refit_args <- function(f, e, cfg) {
  ctrl <- if (isTRUE(f$escalated)) {
    list(adapt_delta = e$escalation$adapt_delta, max_treedepth = e$escalation$max_treedepth)
  } else {
    list(adapt_delta = e$adapt_delta_start, max_treedepth = cfg$sampling$max_treedepth)
  }
  list(seed = f$seed, init_r = e$init_r, control = ctrl, chains = cfg$sampling$chains,
       warmup = e$warmup, iter = e$warmup + e$iter_sampling)
}

# Repair method for a dataset: reloo if both families have a bad-k share
# <= max_prop_bad_k_for_reloo, otherwise grouped K-fold (config/v3.yml).
repair_method <- function(fits, e, cfg3) {
  prop_bad <- purrr::map_dbl(fits, ~ mean(.x$loo$diagnostics$pareto_k > cfg3$loo_robust$k_threshold))
  list(prop_bad = prop_bad,
       method = if (all(prop_bad <= e$loo_repair$max_prop_bad_k_for_reloo)) "reloo" else "kfold")
}

# Grouped folds: one fold per participant (all of a participant's rows
# together), shared by both families; depend only on the dataset name.
make_folds <- function(fits, ds, cfg3) {
  part <- fits[[1]]$fit$data$participant
  stopifnot(identical(part, fits[[2]]$fit$data$participant))
  set.seed(cfg3$seed_base_v3 + sum(utf8ToInt(ds)))
  pf <- loo::kfold_split_random(K = cfg3$loo_robust$kfold_K, N = length(unique(part)))
  pf[match(part, sort(unique(part)))]
}

repair_record <- function(ds, fam, method, prop_bad, res, t0) {
  list(dataset = ds, family = fam, method = method, prop_bad_k = prop_bad, loo_repaired = res,
       ok = !inherits(res, "error"),
       elapsed_secs = as.numeric(difftime(Sys.time(), t0, units = "secs")))
}

# Convergence classes used by the divergence-only sensitivity analysis
# (07_summarise_empirical.R) and by the LOO-repair tiers (05b_loo_tiers.R).
# A fit is "conv_ok" if it passed, or failed ONLY on divergences (R-hat and
# bulk/tail ESS within limits, no tree-depth hits).
fit_flags <- function(fit) if (is.null(fit$diagnostics)) NA_character_ else fit$diagnostics$flags
divergence_only <- function(fit) identical(fit$status, "fail") && identical(sort(fit_flags(fit)), "divergences")
conv_ok <- function(fit) identical(fit$status, "pass") || divergence_only(fit)
