# G0: model-consistent benchmark. Generate data under the equal-variance
# Gaussian meta-d' model via hmetad::sim_metad_participant(), with an
# explicit known log_M, for pipeline/internal validation (protocol
# section 3.1, docs/design_decisions.md).
#
# No between-subject parameter variability is introduced (sd_dprime =
# sd_M = sd_c = 0): every simulated subject shares the same generating
# dprime/log_M, matching G0's role as a "known truth" recovery check.
# Confidence-threshold placement (meta_c2_0/meta_c2_1) keeps a small
# default between-subject spread (sd = 0.1 on the log scale), since
# zero threshold variability would be an unrealistic degenerate case
# and isn't needed for the log_M ground truth to be exact.
#
# log_M is on the log scale directly (sim_metad_participant's mean_M
# under allow_negative_values = FALSE, the locked default -- see
# docs/design_decisions.md's hmetad API notes). metac_absolute = TRUE
# and aggregate-ready trial-level output (stimulus/response/confidence
# already 0/1-coded by the package) per the locked fitting policy.

simulate_g0 <- function(n_participants,
                         n_trials,
                         dprime_target,
                         log_M,
                         k = 4,
                         seed,
                         metac_absolute = TRUE,
                         allow_negative_values = FALSE,
                         mean_z_c2 = -1,
                         sd_z_c2 = 0.1) {
  stopifnot(n_participants >= 1, n_trials >= 1, k >= 2)

  z_len <- k - 1

  data <- withr::with_seed(seed, {
    hmetad::sim_metad_participant(
      N_participants = n_participants,
      N_trials = n_trials,
      mean_dprime = dprime_target, sd_dprime = 0,
      mean_c = 0, sd_c = 0,
      mean_M = log_M, sd_M = 0,
      mean_z_c2_0 = rep(mean_z_c2, z_len), sd_z_c2_0 = rep(sd_z_c2, z_len),
      mean_z_c2_1 = rep(mean_z_c2, z_len), sd_z_c2_1 = rep(sd_z_c2, z_len),
      metac_absolute = metac_absolute,
      allow_negative_values = allow_negative_values,
      summarize = FALSE
    )
  })

  data$log_M_target <- log_M
  data$dprime_target <- dprime_target
  data$k <- k
  data$seed <- seed
  data
}
