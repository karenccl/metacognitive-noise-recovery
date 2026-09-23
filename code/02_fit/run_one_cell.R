# Command-line entry point: takes a single grid_id (a fully-specified
# row of config/grid.csv -- generator, cell params, rep_id, fit_variant,
# and pre-derived sim_seed/fit_seed; see code/00_setup/02_create_grid.R).
# Simplification vs. protocol section 4.2's literal "grid_id and rep_id"
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
# (protocol section 3.1; not part of the grid since it never varies).
log_M_ground_truth <- -1

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

result <- tryCatch(
  {
    data <- simulate_cell(row)
    fit_result <- fit_cell(row, data)
    fit_result$grid_id <- row$grid_id
    fit_result
  },
  error = function(e) {
    list(
      grid_id = row$grid_id, status = "error", error_message = conditionMessage(e),
      fit = NULL, diagnostics = NULL, escalated = NA, warnings = character(0)
    )
  }
)

qs2::qs_save(result, out_path)
cat("Saved:", out_path, " status:", result$status, "\n")
