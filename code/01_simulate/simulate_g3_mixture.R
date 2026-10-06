# G3 (v3, docs/v3_plan.md §4): equal-variance Gaussian meta-d' data with a
# within-participant mixture of difficulty levels (one block per level, each
# simulated by simulate_g0()). Known log_M is shared by all levels. Thresholds
# are drawn independently per level (sd_z_c2 = 0.1 in simulate_g0), a small,
# documented deviation from a participant having identical thresholds across
# difficulty levels. Participant ids match across levels (1..n_participants).

source(here::here("code", "01_simulate", "simulate_g0.R"))

simulate_g3_mixture <- function(n_participants, n_trials_per_level, dprimes,
                                log_M, k = 4, seed) {
  stopifnot(length(dprimes) >= 2)
  out <- purrr::imap_dfr(dprimes, function(dp, i) {
    d <- simulate_g0(n_participants = n_participants, n_trials = n_trials_per_level,
                     dprime_target = dp, log_M = log_M, k = k,
                     seed = seed + (i - 1L) * 100000L)
    d$difficulty   <- paste0("L", i)
    d$dprime_level <- dp
    d
  })
  out$difficulty <- factor(out$difficulty)
  out
}
