# G1: DDM-type confidence generator with post-decisional readout noise
# sigma_c (protocol section 3.2). simulate_g1_ddm() returns trial-level
# data with participant, trial, stimulus, response, correct, rt, latent
# pre/post-decisional evidence q, readout y, binned confidence (1:K),
# and generator metadata (v, a, t0, tau, sigma_c, seed).
#
# Do NOT use a * RT as terminal evidence (see protocol 3.2, "Avoid a
# fatal implementation mistake"). Use an explicit simulated evidence
# trajectory or documented post-decisional accumulation process.
#
# Drift/boundary values must be calibrated to target empirical d' via a
# separate calibration sweep (see docs/design_decisions.md and
# outputs/tables/ddm_calibration.csv), not assumed.

simulate_g1_ddm <- function(...) {
  stop("not yet implemented")
}
