# G2: non-Gaussian signal distribution (gumbel_min) via
# hmetad::sim_metad_participant(distribution = gumbel_min lcdf/lccdf),
# for the controlled distributional-misspecification study (docs/design_decisions.md).
#
# hmetad only exports normal_lcdf/normal_lccdf (both take (x, mu), with
# an implicit fixed unit scale/variance -- see docs/design_decisions.md's
# hmetad API notes). There is no exported gumbel_min equivalent, so this
# file defines one, matching the same (x, mu) contract: a "parameter-free"
# distribution (docs/design_decisions.md; stanvars_metad() docs) with a
# FIXED scale and MEAN-CENTERED at mu, so `mu` plays the same role here
# as it does for the normal case (dprime/meta_c are then comparable in
# spirit across distributions, though never assumed to be on an
# identical numeric scale -- see the design's scale caveat).
#
# Standard Gumbel-min(location = nu, scale = beta) has CDF
#   F(x) = 1 - exp(-exp((x - nu) / beta)),
# mean = nu - gamma*beta (gamma = Euler-Mascheroni constant), and
# variance = (pi^2/6) * beta^2. Fixing beta = sqrt(6)/pi gives unit
# variance (matching the normal's implicit sd = 1), and shifting the
# location so nu = mu + gamma*beta makes the mean exactly mu. Verified
# numerically (mean/variance recovered from the CDF, and lcdf+lccdf
# exponentiate to a valid complementary pair) -- see docs/analysis_log.md.
#
# Fitting the correctly-specified G2 model additionally requires matching
# Stan-side gumbel_min_lcdf/lccdf function definitions (stanvars_metad()'s
# own generated code calls them but does not define them -- see
# docs/design_decisions.md). gumbel_min_stanvars() below supplies them,
# using the identical nu/beta parameterisation as the R functions in this
# file; pass it as `extra_stanvars` to fit_one_hmetad() when
# distribution = "gumbel_min".

gumbel_min_beta <- sqrt(6) / pi
gumbel_min_euler_gamma <- -digamma(1)

gumbel_min_lcdf <- function(x, mu, beta = gumbel_min_beta) {
  nu <- mu + gumbel_min_euler_gamma * beta
  z <- (x - nu) / beta
  # log(1 - exp(-t)) with t = exp(z); expm1 keeps precision when t is small
  log(-expm1(-exp(z)))
}

gumbel_min_lccdf <- function(x, mu, beta = gumbel_min_beta) {
  nu <- mu + gumbel_min_euler_gamma * beta
  z <- (x - nu) / beta
  -exp(z)
}

# Stan-side twin of the R functions above, using Stan's built-in
# log1m_exp(y) = log(1 - exp(y)) (accurate for y <= 0, which -exp(z)
# always is). Must stay numerically identical to gumbel_min_lcdf()/
# gumbel_min_lccdf() -- beta and euler_gamma are inlined as literals
# here since Stan functions can't reference R globals.
gumbel_min_stanvars <- function() {
  brms::stanvar(
    scode = "
  real gumbel_min_lcdf(real x, real mu) {
    real beta = sqrt(6) / pi();
    real euler_gamma = 0.5772156649015329;
    real nu = mu + euler_gamma * beta;
    real z = (x - nu) / beta;
    return log1m_exp(-exp(z));
  }
  real gumbel_min_lccdf(real x, real mu) {
    real beta = sqrt(6) / pi();
    real euler_gamma = 0.5772156649015329;
    real nu = mu + euler_gamma * beta;
    real z = (x - nu) / beta;
    return -exp(z);
  }
",
    block = "functions"
  )
}

simulate_g2_gumbel <- function(n_participants,
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
      r_z_c2_0 = diag(z_len), r_z_c2_1 = diag(z_len),
      metac_absolute = metac_absolute,
      allow_negative_values = allow_negative_values,
      lcdf = gumbel_min_lcdf, lccdf = gumbel_min_lccdf,
      summarize = FALSE
    )
  })

  data$log_M_target <- log_M
  data$dprime_target <- dprime_target
  data$distribution <- "gumbel_min"
  data$k <- k
  data$seed <- seed
  data
}
