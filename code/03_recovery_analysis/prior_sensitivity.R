# Refit a fixed moderate-information design (N=40, T=200) and one
# representative G0/G1 condition under three predeclared population
# log_M priors (normal(0,0.5), normal(0,1), normal(0,2), locked in
# config/design.yml's priors.log_M_sensitivity) on the EXACT same
# simulated dataset per generator. Plot posterior median, 95% interval,
# and posterior/prior overlap (docs/design_decisions.md; Day 4 midday).
#
# "Exact same simulated dataset" is achieved by regenerating the trial-
# level data with the grid row's own recorded sim_seed (deterministic
# generators), then calling fit_one_hmetad() with the SAME fit_seed
# across all three priors -- isolates the prior's effect from sampler
# RNG noise, not just from generator RNG noise.
#
# Run from the project root: Rscript code/03_recovery_analysis/prior_sensitivity.R

suppressPackageStartupMessages(library(dplyr))

`%||%` <- function(x, y) if (is.null(x)) y else x

source(here::here("code", "01_simulate", "discretise_confidence.R"))
source(here::here("code", "01_simulate", "simulate_g1_ddm.R"))
source(here::here("code", "01_simulate", "simulate_g0.R"))
source(here::here("code", "02_fit", "extract_fit_summary.R"))
source(here::here("code", "02_fit", "fit_hmetad.R"))

cfg <- yaml::read_yaml(here::here("config", "design.yml"))
grid <- readr::read_csv(here::here("config", "grid.csv"), show_col_types = FALSE)
log_M_ground_truth <- yaml::read_yaml(here::here("config", "design.yml"))$truth$log_M

# --- Representative conditions: N=40, T=200, dprime_target=1.5, rep 1 ------

g0_row <- grid |>
  dplyr::filter(generator == "g0", n_participants == 40, n_trials == 200,
                dprime_target == 1.5, rep_id == 1)
g1_row <- grid |>
  dplyr::filter(generator == "g1", n_participants == 40, n_trials == 200,
                dprime_target == 1.5, sigma_c_level == "medium", rep_id == 1)
stopifnot(nrow(g0_row) == 1, nrow(g1_row) == 1)

cat("G0 representative row: grid_id", g0_row$grid_id, "sim_seed", g0_row$sim_seed, "\n")
cat("G1 representative row: grid_id", g1_row$grid_id, "sim_seed", g1_row$sim_seed, "\n")

g0_data <- simulate_g0(
  n_participants = g0_row$n_participants, n_trials = g0_row$n_trials,
  dprime_target = g0_row$dprime_target, log_M = log_M_ground_truth,
  k = cfg$confidence$k, seed = g0_row$sim_seed
)
g1_v <- cfg$ddm$v_by_dprime_target[[as.character(g1_row$dprime_target)]]
g1_sigma_c <- cfg$ddm$sigma_c_values[[g1_row$sigma_c_level]]
g1_data <- simulate_g1_ddm(
  n_participants = g1_row$n_participants, n_trials = g1_row$n_trials,
  v = g1_v, a = cfg$ddm$a, t0 = cfg$ddm$t0, tau = cfg$ddm$tau,
  sigma_c = g1_sigma_c, s = cfg$ddm$s, dt = cfg$ddm$dt,
  k = cfg$confidence$k, seed = g1_row$sim_seed
)

priors <- unlist(cfg$priors$log_M_sensitivity)
cat("\nPriors to sweep:", paste(priors, collapse = "; "), "\n")

refit_under_prior <- function(data, row, prior, label) {
  cat(sprintf("Fitting %s under prior %s...\n", label, prior))
  fit_one_hmetad(
    data, K = cfg$confidence$k, group = "participant",
    hierarchical_dprime_c = cfg$fitting$hierarchical_dprime_c,
    hierarchical_thresholds = cfg$fitting$hierarchical_thresholds,
    log_M_prior = prior, metac2_prior = cfg$priors$metac2_gap,
    chains = cfg$sampling$chains, cores = cfg$sampling$chains,
    warmup = cfg$sampling$warmup, iter_sampling = cfg$sampling$iter_sampling,
    adapt_delta = cfg$sampling$adapt_delta, max_treedepth = cfg$sampling$max_treedepth,
    rhat_max = cfg$diagnostics$rhat_max, bulk_ess_min = cfg$diagnostics$bulk_ess_min,
    tail_ess_min = cfg$diagnostics$tail_ess_min,
    seed = row$fit_seed,  # SAME seed across all 3 priors -- isolates the prior's effect
    metadata = list(generator = label, prior = prior)
  )
}

fits <- list()
draws_list <- list()
for (p in priors) {
  fits[[paste0("g0_", p)]] <- refit_under_prior(g0_data, g0_row, p, "g0")
  fits[[paste0("g1_", p)]] <- refit_under_prior(g1_data, g1_row, p, "g1")
}

# --- Posterior summary + prior/posterior overlap ---------------------------
# Prior density evaluated on the log_M scale (all three priors are
# normal(0, sd) on this same scale, per config/design.yml).

parse_normal_sd <- function(prior_string) {
  as.numeric(sub(".*,\\s*([0-9.]+)\\s*\\)", "\\1", prior_string))
}

# key = "<generator>_<prior string>", e.g. "g0_normal(0, 0.5)". The prior
# strings contain no underscores, so splitting on the first "_" cleanly
# separates generator from the (unmodified) prior string.
split_key <- function(key) {
  parts <- strsplit(key, "_", fixed = TRUE)[[1]]
  list(generator = parts[1], prior = paste(parts[-1], collapse = "_"))
}

extract_log_M_draws <- function(f) posterior::as_draws_df(f$fit)$b_Intercept

summary_rows <- purrr::map_dfr(names(fits), function(key) {
  f <- fits[[key]]
  draws <- extract_log_M_draws(f)
  parts <- split_key(key)

  tibble::tibble(
    generator = parts$generator,
    prior = parts$prior,
    status = f$status,
    log_M_mean = mean(draws), log_M_median = stats::median(draws),
    log_M_sd = stats::sd(draws),
    log_M_q025 = stats::quantile(draws, 0.025, names = FALSE),
    log_M_q975 = stats::quantile(draws, 0.975, names = FALSE),
    prior_sd = parse_normal_sd(parts$prior)
  )
})

summary_rows <- summary_rows |> dplyr::arrange(generator, prior_sd)

readr::write_csv(summary_rows, here::here("data", "processed", "prior_sensitivity_summary.csv"))
cat("\n=== Prior sensitivity summary ===\n")
print(summary_rows)

# --- Plot: posterior median + 95% CI across priors, with prior density overlay

plot_data <- summary_rows |> dplyr::mutate(prior_label = factor(prior, levels = priors))

draws_df <- purrr::map_dfr(names(fits), function(key) {
  f <- fits[[key]]
  parts <- split_key(key)
  tibble::tibble(generator = parts$generator, prior = parts$prior, draw = extract_log_M_draws(f))
}) |>
  dplyr::mutate(prior_label = factor(prior, levels = priors))

p <- ggplot2::ggplot() +
  ggplot2::geom_violin(
    data = draws_df, ggplot2::aes(x = prior_label, y = draw, fill = prior_label),
    alpha = 0.4, trim = TRUE, show.legend = FALSE
  ) +
  ggplot2::geom_pointrange(
    data = plot_data,
    ggplot2::aes(x = prior_label, y = log_M_median, ymin = log_M_q025, ymax = log_M_q975),
    color = "black", size = 0.6
  ) +
  ggplot2::geom_hline(
    data = tibble::tibble(generator = "g0", log_M_ground_truth = log_M_ground_truth),
    ggplot2::aes(yintercept = log_M_ground_truth), linetype = "dashed", color = "red"
  ) +
  ggplot2::facet_wrap(~generator, labeller = ggplot2::labeller(
    generator = c(g0 = "G0 (Gaussian benchmark)", g1 = "G1 (DDM, sigma_c=medium)")
  )) +
  ggplot2::labs(
    title = "Prior sensitivity: posterior log_M by prior width",
    subtitle = "N=40, T=200, d'=1.5 (G1: sigma_c=medium); red line = known truth (G0 only; G1 has no single true log_M)",
    x = "Population log_M prior", y = "Posterior log_M (draws, median, 95% CI)"
  ) +
  ggplot2::theme_minimal()

ggplot2::ggsave(here::here("outputs", "figures", "prior_sensitivity.png"), p, width = 8, height = 5, dpi = 150)
cat("\nWrote outputs/figures/prior_sensitivity.png\n")
cat("Wrote data/processed/prior_sensitivity_summary.csv\n")
cat("Done.\n")
