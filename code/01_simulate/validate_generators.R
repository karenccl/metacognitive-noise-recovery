# Preliminary simulator validation: DDM drift-to-d' calibration,
# sigma_c low/medium/high pilot, and degeneracy diagnostics, run before
# committing to the primary grid (docs/design_decisions.md; Day 1 gate; see
# docs/design_decisions.md for the calibration plan this implements).
#
# Outputs:
#   outputs/tables/ddm_calibration.csv  -- drift v calibrated to each
#     dprime_target, at fixed a/t0 (config/design.yml ddm: block)
#   outputs/tables/sigma_c_pilot.csv    -- the sigma_c sweep used to
#     choose the low/medium/high grid values
#
# Run from the project root:
#   Rscript code/01_simulate/validate_generators.R

suppressPackageStartupMessages({
  library(dplyr)
})

source(here::here("code", "01_simulate", "discretise_confidence.R"))
source(here::here("code", "01_simulate", "simulate_g1_ddm.R"))

cfg <- yaml::read_yaml(here::here("config", "design.yml"))

# ---------------------------------------------------------------------------
# 1. Drift (v) calibration to target empirical d', at fixed a/t0.
#    Bisection on v; same seed reused across iterations (common random
#    numbers) so empirical d'(v) is a smooth, near-monotonic function of
#    v and bisection converges cleanly.
# ---------------------------------------------------------------------------

calibrate_drift <- function(target_d, a, t0, s = 1, dt = 0.001,
                             n_trials = 100000, tol = 0.02,
                             v_lo = 0.1, v_hi = 6, max_iter = 40, seed) {
  eval_v <- function(v) {
    withr::with_seed(seed, {
      stim <- sample(c(-1L, 1L), n_trials, replace = TRUE)
      drift <- stim * v
      dec <- .ddm_decision_phase(drift = drift, a = a, s = s, dt = dt, max_steps = 50000)
      resp <- ifelse(dec$hit_upper, 1L, -1L)
      H <- mean(resp[stim == 1] == 1)
      FA <- mean(resp[stim == -1] == 1)
      p_correct <- mean(resp == stim)
      mean_rt <- mean(t0 + dec$n_steps * dt)
      list(H = H, FA = FA, p_correct = p_correct, mean_rt = mean_rt)
    })
  }
  clamp <- function(p) pmin(pmax(p, 1e-4), 1 - 1e-4)
  emp_d <- function(r) stats::qnorm(clamp(r$H)) - stats::qnorm(clamp(r$FA))

  lo <- v_lo
  hi <- v_hi
  r <- eval_v(hi)
  if (emp_d(r) < target_d) {
    stop("v_hi too small to reach target_d = ", target_d, " (got ", round(emp_d(r), 3), ")")
  }

  for (i in seq_len(max_iter)) {
    v_mid <- (lo + hi) / 2
    r <- eval_v(v_mid)
    d_emp <- emp_d(r)
    if (abs(d_emp - target_d) < tol) break
    if (d_emp < target_d) lo <- v_mid else hi <- v_mid
  }

  tibble::tibble(
    dprime_target = target_d,
    v = v_mid,
    a = a,
    t0 = t0,
    empirical_dprime_hit_fa = d_emp,
    empirical_dprime_pcorrect = 2 * stats::qnorm(clamp(r$p_correct)),
    hit_rate = r$H,
    fa_rate = r$FA,
    p_correct = r$p_correct,
    mean_rt = r$mean_rt,
    n_trials = n_trials,
    seed = seed,
    iterations = i,
    tol = tol
  )
}

seed_base <- cfg$seed_base
a_start <- cfg$ddm$a
t0_start <- cfg$ddm$t0
dprime_targets <- unlist(cfg$grid$dprime_target)

calibration <- purrr::map_dfr(
  seq_along(dprime_targets),
  function(i) {
    calibrate_drift(
      target_d = dprime_targets[i], a = a_start, t0 = t0_start,
      dt = cfg$ddm$dt, tol = cfg$ddm$dprime_tolerance,
      seed = seed_base + 100L + i
    )
  }
)

dir.create(here::here("outputs", "tables"), showWarnings = FALSE, recursive = TRUE)
readr::write_csv(calibration, here::here("outputs", "tables", "ddm_calibration.csv"))

cat("=== DDM drift calibration ===\n")
print(calibration)

max_disagreement <- max(abs(calibration$empirical_dprime_hit_fa - calibration$empirical_dprime_pcorrect))
cat("\nMax disagreement between d' formulas:", round(max_disagreement, 4), "\n")
if (max_disagreement > 0.05) {
  warning(
    "empirical_dprime_hit_fa and empirical_dprime_pcorrect disagree by more than 0.05 ",
    "for at least one target -- check for response bias/asymmetry."
  )
}

# ---------------------------------------------------------------------------
# 2. sigma_c low/medium/high pilot.
#    Simulate the decision+post-decision stages ONCE at the largest
#    calibrated d' (q does not depend on sigma_c), then sweep sigma_c by
#    only re-drawing the readout noise, which is fast and uses a shared
#    evidence realisation across the whole sweep.
# ---------------------------------------------------------------------------

v_for_pilot <- calibration$v[which.max(calibration$dprime_target)]
pilot_seed <- seed_base + 200L
n_pilot_trials <- 20000L

pilot_base <- withr::with_seed(pilot_seed, {
  stim <- sample(c(-1L, 1L), n_pilot_trials, replace = TRUE)
  drift <- stim * v_for_pilot
  dec <- .ddm_decision_phase(drift = drift, a = a_start, s = cfg$ddm$s, dt = cfg$ddm$dt, max_steps = 50000)
  x_post <- .ddm_postdecision_phase(
    x0 = dec$x_at_decision, drift = drift, tau = cfg$ddm$tau, s = cfg$ddm$s, dt = cfg$ddm$dt
  )
  resp <- ifelse(dec$hit_upper, 1L, -1L)
  q <- (x_post - a_start / 2) * resp
  correct <- as.integer(stim == resp)
  list(q = q, correct = correct)
})

sd_q <- stats::sd(pilot_base$q)
cat("\nSD(q) at calibrated v =", round(v_for_pilot, 3), ":", round(sd_q, 4), "\n")

sigma_c_candidates <- sd_q * c(0.05, 0.1, 0.2, 0.35, 0.5, 0.75, 1, 1.5, 2, 3, 5, 8)

pilot_seed_noise <- seed_base + 201L
sigma_c_pilot <- purrr::map_dfr(sigma_c_candidates, function(sc) {
  y <- withr::with_seed(pilot_seed_noise, {
    pilot_base$q + stats::rnorm(n_pilot_trials, mean = 0, sd = sc)
  })
  d <- tibble::tibble(participant = 1L, y = y)
  disc <- discretise_confidence(d, "participant", "y", k = cfg$confidence$k)
  confidence <- disc$data$confidence

  tibble::tibble(
    sigma_c = sc,
    sigma_c_over_sd_q = sc / sd_q,
    cor_q_y = stats::cor(pilot_base$q, y, method = "spearman"),
    cor_confidence_correct = stats::cor(confidence, pilot_base$correct, method = "spearman"),
    prop_tied_y = mean(duplicated(y) | duplicated(y, fromLast = TRUE)),
    n_degenerate_cutpoints = disc$cutpoints$n_degenerate_cutpoints[1]
  )
})

readr::write_csv(sigma_c_pilot, here::here("outputs", "tables", "sigma_c_pilot.csv"))

cat("\n=== sigma_c pilot sweep ===\n")
print(sigma_c_pilot)

# Choose low/medium/high as the candidates whose confidence-accuracy
# association is closest to three target levels spanning the observed
# range (near-ceiling, mid, near-floor), rather than evenly-spaced sigma_c
# values -- the point is a distinguishable, nondegenerate spread of
# informativeness, not arbitrary noise magnitudes (docs/design_decisions.md).
assoc_range <- range(sigma_c_pilot$cor_confidence_correct)
targets <- assoc_range[2] - diff(assoc_range) * c(0.15, 0.5, 0.85)
pick_idx <- sapply(targets, function(t) which.min(abs(sigma_c_pilot$cor_confidence_correct - t)))
chosen <- sigma_c_pilot[pick_idx, ]
chosen$level <- c("low", "medium", "high")

cat("\n=== chosen low/medium/high sigma_c ===\n")
print(chosen[, c("level", "sigma_c", "sigma_c_over_sd_q", "cor_q_y", "cor_confidence_correct")])

readr::write_csv(chosen, here::here("outputs", "tables", "sigma_c_chosen.csv"))

cat("\nDone. See outputs/tables/ddm_calibration.csv, outputs/tables/sigma_c_pilot.csv,\n")
cat("outputs/tables/sigma_c_chosen.csv. Update config/design.yml and\n")
cat("docs/design_decisions.md with these values.\n")
