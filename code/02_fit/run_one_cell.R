# Command-line entry point: takes a single grid_id (a fully-specified
# row of config/grid.csv -- generator, cell params, rep_id, fit_variant,
# and pre-derived sim_seed/fit_seed; see code/00_setup/02_create_grid.R).
# Simplification vs. the design's literal "grid_id and rep_id"
# wording: rep_id is already a grid.csv column, so grid_id alone fully
# determines the row -- no scientific effect, just one fewer CLI arg.
#
# Checks whether output already exists (resumable), simulates, fits
# (with one escalation retry per config/design.yml's escalation policy
# on "refit"-flagged fits), and saves an atomic result to
# data/interim/<generator>_cell-<cell_id>_rep-<rep_id>[_<fit_variant>]_grid-<grid_id>.qs2.
# Wrapped in tryCatch() so failures write a structured error record
# instead of crashing the batch.
#
# Output format (revised 2026-09-23 -- full brmsfit objects are large
# and 30(then 20) reps x 72 cells would not fit comfortably on disk):
# every row saves a COMPACT record -- status/diagnostics/escalation/
# warnings/grid metadata, posterior draws for b_*/sd_* parameters only
# (not the full posterior), and the aggregated observed counts. The
# full brmsfit is additionally kept only when
# config's execution.keep_full_fit_max_rep_id >= rep_id, for spot-
# checking/debugging without keeping every replication's fit object.
# For G2 rows (both fit variants), also computes and saves a loo()
# object and a per-cell posterior-predictive summary (mean/median/95%
# interval of epred_draws_metad(), not the raw per-draw output) for
# the Day-5 PPC and G2 LOO-comparison scripts. See docs/design_decisions.md.
#
# Usage: Rscript code/02_fit/run_one_cell.R <grid_id>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: Rscript run_one_cell.R <grid_id>")
grid_id <- as.integer(args[1])

source(here::here("code", "01_simulate", "discretise_confidence.R"))
source(here::here("code", "01_simulate", "simulate_g1_ddm.R"))
source(here::here("code", "01_simulate", "simulate_g0.R"))
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "02_fit", "extract_fit_summary.R"))
source(here::here("code", "02_fit", "fit_hmetad.R"))

cfg <- yaml::read_yaml(here::here("config", "design.yml"))
grid <- readr::read_csv(here::here("config", "grid.csv"), show_col_types = FALSE)
row <- grid[grid$grid_id == grid_id, ]
if (nrow(row) != 1) stop("grid_id ", grid_id, " not found (or not unique) in config/grid.csv")
row <- as.list(row)

# Known-truth ground for G0/G2's known-parameter recovery check
# (docs/design_decisions.md; not part of the grid since it never varies).
log_M_ground_truth <- yaml::read_yaml(here::here("config", "design.yml"))$truth$log_M

out_dir <- here::here("data", "interim")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
variant_suffix <- if (row$fit_variant != "default") paste0("_", row$fit_variant) else ""
out_path <- file.path(out_dir, sprintf(
  "%s_cell-%04d_rep-%02d%s_grid-%05d.qs2",
  row$generator, row$cell_id, row$rep_id, variant_suffix, row$grid_id
))

if (file.exists(out_path)) {
  cat("Output already exists, skipping:", out_path, "\n")
  quit(save = "no", status = 0)
}

simulate_cell <- function(row) {
  if (row$generator == "g0") {
    simulate_g0(
      n_participants = row$n_participants, n_trials = row$n_trials,
      dprime_target = row$dprime_target, log_M = log_M_ground_truth,
      k = cfg$confidence$k, seed = row$sim_seed
    )
  } else if (row$generator == "g1") {
    v <- cfg$ddm$v_by_dprime_target[[as.character(row$dprime_target)]]
    sigma_c <- cfg$ddm$sigma_c_values[[row$sigma_c_level]]
    simulate_g1_ddm(
      n_participants = row$n_participants, n_trials = row$n_trials,
      v = v, a = cfg$ddm$a, t0 = cfg$ddm$t0, tau = cfg$ddm$tau,
      sigma_c = sigma_c, s = cfg$ddm$s, dt = cfg$ddm$dt,
      k = cfg$confidence$k, seed = row$sim_seed
    )
  } else if (row$generator == "g2") {
    simulate_g2_gumbel(
      n_participants = row$n_participants, n_trials = row$n_trials,
      dprime_target = row$dprime_target, log_M = log_M_ground_truth,
      k = cfg$confidence$k, seed = row$sim_seed
    )
  } else {
    stop("unknown generator: ", row$generator)
  }
}

fit_cell_once <- function(row, data, distribution, seed, adapt_delta, max_treedepth, extra_stanvars) {
  fit_one_hmetad(
    data, K = cfg$confidence$k, group = "participant",
    distribution = distribution, metac_absolute = cfg$fitting$metac_absolute,
    hierarchical_dprime_c = cfg$fitting$hierarchical_dprime_c,
    hierarchical_thresholds = cfg$fitting$hierarchical_thresholds,
    log_M_prior = cfg$priors$log_M_production, metac2_prior = cfg$priors$metac2_gap,
    chains = cfg$sampling$chains, warmup = cfg$sampling$warmup,
    iter_sampling = cfg$sampling$iter_sampling,
    adapt_delta = adapt_delta, max_treedepth = max_treedepth,
    rhat_max = cfg$diagnostics$rhat_max, bulk_ess_min = cfg$diagnostics$bulk_ess_min,
    tail_ess_min = cfg$diagnostics$tail_ess_min,
    seed = seed, extra_stanvars = extra_stanvars,
    metadata = row
  )
}

fit_cell <- function(row, data) {
  is_g2_correct <- row$generator == "g2" && row$fit_variant == "correct"
  distribution <- if (is_g2_correct) "gumbel_min" else "normal"
  extra_stanvars <- if (is_g2_correct) gumbel_min_stanvars() else NULL

  attempt <- fit_cell_once(
    row, data, distribution, seed = row$fit_seed,
    adapt_delta = cfg$sampling$adapt_delta, max_treedepth = cfg$sampling$max_treedepth,
    extra_stanvars = extra_stanvars
  )
  attempt$escalated <- FALSE

  if (identical(attempt$status, "refit")) {
    attempt <- fit_cell_once(
      row, data, distribution, seed = row$fit_seed + 1L,
      adapt_delta = cfg$sampling$escalation$adapt_delta,
      max_treedepth = cfg$sampling$escalation$max_treedepth,
      extra_stanvars = extra_stanvars
    )
    attempt$escalated <- TRUE
    if (identical(attempt$status, "refit")) attempt$status <- "fail"
  }
  attempt
}

# Posterior draws for population-level effects and random-effect SDs
# only -- excludes the numerous per-subject r_participant[...] deviations
# and (implicitly, since as_draws_df only returns what's asked) the
# raw Stan internals. Mirrors extract_fit_summary()'s focal-parameter
# selection so the two stay consistent.
extract_b_sd_draws <- function(fit) {
  draws <- posterior::as_draws_df(fit)
  focal_cols <- grep("^b_|^sd_|^\\.chain$|^\\.iteration$|^\\.draw$", names(draws), value = TRUE)
  tibble::as_tibble(draws[, focal_cols])
}

# Per-cell (participant x stimulus x response x confidence) posterior
# predictive SUMMARY, not raw per-draw output -- a full per-draw
# epred_draws_metad() over all participants would be
# n_participants x 4K x n_draws rows, which defeats the point of
# slimming this output down. Observed counts for the same cells are
# already in agg (saved separately), so the Day-5 PPC script joins the
# two rather than this function duplicating the observed side.
summarise_epred <- function(fit, agg) {
  ep <- hmetad::epred_draws_metad(fit, agg)
  ep |>
    dplyr::group_by(participant, stimulus, response, confidence, joint_response) |>
    dplyr::summarise(
      epred_mean = mean(.epred),
      epred_median = stats::median(.epred),
      epred_q025 = stats::quantile(.epred, 0.025),
      epred_q975 = stats::quantile(.epred, 0.975),
      .groups = "drop"
    )
}

# G2-only extras (both fit variants -- G2's whole point is comparing
# correct-vs-misspecified LOO/PPC, the design). Computed
# even for the escalated/failed case if a fit object exists, since a
# high-Pareto-k or poor-PPC fit is itself informative, not just passes.
add_g2_extras <- function(attempt, agg) {
  if (is.null(attempt$fit)) {
    attempt$loo <- NULL
    attempt$epred_summary <- NULL
    return(attempt)
  }
  attempt$loo <- tryCatch(brms::loo(attempt$fit), error = function(e) {
    warning("loo() failed: ", conditionMessage(e))
    NULL
  })
  attempt$epred_summary <- tryCatch(summarise_epred(attempt$fit, agg), error = function(e) {
    warning("epred summary failed: ", conditionMessage(e))
    NULL
  })
  attempt
}

# Strip the full brmsfit unless this replication is within the
# keep-for-debugging window; always attach the compact b_*/sd_* draws
# first (needs the full fit to extract them from).
build_compact_result <- function(attempt, row) {
  if (!is.null(attempt$fit)) {
    attempt$draws_b_sd <- tryCatch(extract_b_sd_draws(attempt$fit), error = function(e) NULL)
  } else {
    attempt$draws_b_sd <- NULL
  }

  if (row$generator == "g2") {
    attempt <- add_g2_extras(attempt, attempt$agg)
  }

  keep_full_fit <- row$rep_id <= cfg$execution$keep_full_fit_max_rep_id
  if (!keep_full_fit) attempt$fit <- NULL

  attempt
}

result <- tryCatch(
  {
    data <- simulate_cell(row)
    fit_result <- fit_cell(row, data)
    fit_result$grid_id <- row$grid_id
    build_compact_result(fit_result, row)
  },
  error = function(e) {
    list(
      grid_id = row$grid_id, status = "error", error_message = conditionMessage(e),
      fit = NULL, diagnostics = NULL, escalated = NA, warnings = character(0),
      draws_b_sd = NULL, loo = NULL, epred_summary = NULL
    )
  }
)

qs2::qs_save(result, out_path)
cat("Saved:", out_path, " status:", result$status, "\n")
