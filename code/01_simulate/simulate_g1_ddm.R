# G1: DDM-type confidence generator with post-decisional readout noise
# sigma_c (docs/design_decisions.md). Returns
# trial-level data with participant, trial, stimulus, response, correct,
# rt, latent pre/post-decisional evidence q, readout y, binned
# confidence (1:K), and generator metadata (v, a, t0, tau, sigma_c, seed).
#
# Do NOT use a * RT as terminal evidence (the design's named fatal
# mistake). q below is always read directly off the simulated
# accumulator trajectory.
#
# Depends on discretise_confidence() (code/01_simulate/discretise_confidence.R)
# being loaded, and on `withr`, `dplyr`, `tidyr`, `tibble`.
#
# Drift/boundary values must be calibrated to target empirical d' via a
# separate calibration sweep (see docs/design_decisions.md and
# outputs/tables/ddm_calibration.csv), not assumed.

# Decision-stage Euler-Maruyama simulation, vectorised across trials: at
# each time step, only still-active trials are updated, so the cost of
# a slow trial's remaining steps is paid only for that trial.
.ddm_decision_phase <- function(drift, a, s = 1, dt = 0.001, max_steps = 50000) {
  n <- length(drift)
  x <- rep(a / 2, n)
  active <- rep(TRUE, n)
  hit_upper <- rep(NA, n)
  n_steps <- integer(n)
  sqdt <- s * sqrt(dt)
  step <- 0L

  while (any(active) && step < max_steps) {
    step <- step + 1L
    idx <- which(active)
    x[idx] <- x[idx] + drift[idx] * dt + sqdt * stats::rnorm(length(idx))
    crossed_upper <- x[idx] >= a
    crossed_lower <- x[idx] <= 0
    crossed <- crossed_upper | crossed_lower
    if (any(crossed)) {
      done_idx <- idx[crossed]
      hit_upper[done_idx] <- crossed_upper[crossed]
      n_steps[done_idx] <- step
      active[done_idx] <- FALSE
    }
  }

  if (any(active)) {
    warning(
      sum(active), " of ", n, " trial(s) did not reach a decision boundary ",
      "within max_steps = ", max_steps, "; treating as non-decisions (NA)."
    )
  }

  list(hit_upper = hit_upper, n_steps = n_steps, x_at_decision = x)
}

# Post-decisional continuation: the SAME accumulator continues from
# x_at_decision for a further fixed duration tau, with no absorbing
# boundary, so post-decisional evidence can move back across the
# choice boundary (docs/design_decisions.md, G1 DGP step 4).
.ddm_postdecision_phase <- function(x0, drift, tau, s = 1, dt = 0.001) {
  n_tau_steps <- max(0L, round(tau / dt))
  if (n_tau_steps == 0L) {
    return(x0)
  }
  x <- x0
  sqdt <- s * sqrt(dt)
  n <- length(x0)
  for (step in seq_len(n_tau_steps)) {
    x <- x + drift * dt + sqdt * stats::rnorm(n)
  }
  x
}

simulate_g1_ddm <- function(n_participants,
                             n_trials,
                             v,
                             a,
                             t0,
                             tau,
                             sigma_c,
                             s = 1,
                             dt = 0.001,
                             k = 4,
                             seed,
                             max_steps = 50000) {
  stopifnot(
    n_participants >= 1, n_trials >= 1,
    a > 0, t0 >= 0, tau >= 0, sigma_c >= 0, dt > 0
  )

  n_total <- n_participants * n_trials

  sim <- withr::with_seed(seed, {
    stimulus_pm1 <- sample(c(-1L, 1L), n_total, replace = TRUE)
    drift <- stimulus_pm1 * v

    decision <- .ddm_decision_phase(drift = drift, a = a, s = s, dt = dt, max_steps = max_steps)
    x_post <- .ddm_postdecision_phase(
      x0 = decision$x_at_decision, drift = drift, tau = tau, s = s, dt = dt
    )

    response_pm1 <- ifelse(decision$hit_upper, 1L, -1L)
    # Sign-flip by the response actually made: q > 0 means evidence
    # accumulated *for the choice made*, regardless of which boundary
    # that was (docs/design_decisions.md, G1 DGP step 5). q can go negative (post-decisional
    # evidence against the choice made) -- intended, not a bug.
    q <- (x_post - a / 2) * response_pm1
    y <- q + stats::rnorm(n_total, mean = 0, sd = sigma_c)

    tibble::tibble(
      participant = rep(seq_len(n_participants), each = n_trials),
      trial = rep(seq_len(n_trials), times = n_participants),
      stimulus = as.integer(stimulus_pm1 == 1L),
      response = as.integer(response_pm1 == 1L),
      correct = as.integer(stimulus_pm1 == response_pm1),
      rt = t0 + decision$n_steps * dt,
      q = q,
      y = y,
      v = v, a = a, t0 = t0, tau = tau, sigma_c = sigma_c, seed = seed
    )
  })

  discretised <- discretise_confidence(sim, participant_col = "participant", value_col = "y", k = k)

  out <- discretised$data
  attr(out, "cutpoints") <- discretised$cutpoints
  attr(out, "category_counts") <- discretised$category_counts
  attr(out, "tie_summary") <- discretised$tie_summary
  out
}
