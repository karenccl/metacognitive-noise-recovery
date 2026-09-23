library(testthat)

source(here::here("code", "01_simulate", "discretise_confidence.R"))
source(here::here("code", "01_simulate", "simulate_g1_ddm.R"))
source(here::here("code", "01_simulate", "simulate_g0.R"))
source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "02_fit", "extract_fit_summary.R"))
source(here::here("code", "02_fit", "fit_hmetad.R"))

check_schema <- function(d) {
  expect_true(all(c("participant", "stimulus", "response", "confidence") %in% names(d)))
  expect_true(all(d$stimulus %in% 0:1))
  expect_true(all(d$response %in% 0:1))
  expect_true(all(d$confidence %in% 1:4))
}

test_that("G1 (DDM) data passes schema checks and aggregation", {
  skip_if_not_installed("hmetad")
  d <- simulate_g1_ddm(
    n_participants = 5, n_trials = 100,
    v = 1.2, a = 1.5, t0 = 0.3, tau = 0.3, sigma_c = 0.5, seed = 1
  )
  check_schema(d)

  agg <- hmetad::aggregate_metad(d, participant, K = 4)
  expect_equal(nrow(agg), 5)
})

test_that("G0 (Gaussian benchmark) data passes schema checks and aggregation", {
  skip_if_not_installed("hmetad")
  d <- simulate_g0(n_participants = 5, n_trials = 100, dprime_target = 1.5, log_M = -1, seed = 2)
  check_schema(d)

  agg <- hmetad::aggregate_metad(d, participant, K = 4)
  expect_equal(nrow(agg), 5)

  # known-truth ground: M column should be exactly exp(log_M) for every row
  # (no between-subject M variability by design -- see simulate_g0.R)
  expect_equal(unique(d$M), exp(-1), tolerance = 1e-8)
})

test_that("G2 (gumbel_min) data passes schema checks and aggregation", {
  skip_if_not_installed("hmetad")
  d <- simulate_g2_gumbel(n_participants = 5, n_trials = 100, dprime_target = 1.5, log_M = -1, seed = 3)
  check_schema(d)
  expect_true(all(d$distribution == "gumbel_min"))

  agg <- hmetad::aggregate_metad(d, participant, K = 4)
  expect_equal(nrow(agg), 5)
})

test_that("gumbel_min_lcdf/lccdf form a valid complementary CDF pair", {
  xs <- seq(-4, 4, by = 0.5)
  mu <- 0.75
  F <- exp(gumbel_min_lcdf(xs, mu))
  S <- exp(gumbel_min_lccdf(xs, mu))
  expect_equal(F + S, rep(1, length(xs)), tolerance = 1e-10)
  expect_false(is.unsorted(F))
})

# fit_one_hmetad() input validation (fast, no MCMC -- actual fitting is
# exercised manually/in the Day 2 G0 baseline, see docs/analysis_log.md,
# since a single fit takes ~1-2 minutes even at small settings)
test_that("fit_one_hmetad validates required columns and coding before fitting", {
  skip_if_not_installed("hmetad")
  d <- simulate_g0(n_participants = 5, n_trials = 20, dprime_target = 1.5, log_M = -1, seed = 1)

  d_bad_conf <- d
  d_bad_conf$confidence[1] <- 99L
  expect_error(fit_one_hmetad(d_bad_conf, K = 4, seed = 1), "confidence")

  d_missing <- d[, setdiff(names(d), "response")]
  expect_error(fit_one_hmetad(d_missing, K = 4, seed = 1), "missing required column")

  d_bad_stim <- d
  d_bad_stim$stimulus[1] <- 2L
  expect_error(fit_one_hmetad(d_bad_stim, K = 4, seed = 1), "stimulus")
})

test_that(".build_metad_formula and .build_metad_priors produce a buildable (empty) brmsfit", {
  skip_if_not_installed("hmetad")
  d <- simulate_g0(n_participants = 5, n_trials = 20, dprime_target = 1.5, log_M = -1, seed = 1)
  agg <- hmetad::aggregate_metad(d, participant, K = 4)

  formula <- .build_metad_formula(4, group = "participant")
  priors <- .build_metad_priors(4, log_M_prior = "normal(0,1)", metac2_prior = "normal(0,1)")

  fit <- hmetad::fit_metad(formula, agg, aggregate = FALSE, K = 4, prior = priors, empty = TRUE)
  expect_s3_class(fit, "brmsfit")
})

test_that("gumbel_min_stanvars() produces Stan code that builds (empty) with distribution='gumbel_min'", {
  skip_if_not_installed("hmetad")
  d <- simulate_g0(n_participants = 5, n_trials = 20, dprime_target = 1.5, log_M = -1, seed = 1)
  agg <- hmetad::aggregate_metad(d, participant, K = 4)

  formula <- .build_metad_formula(4, group = "participant")
  priors <- .build_metad_priors(4, log_M_prior = "normal(0,1)", metac2_prior = "normal(0,1)")

  fit <- hmetad::fit_metad(
    formula, agg, aggregate = FALSE, K = 4,
    distribution = "gumbel_min", prior = priors,
    stanvars = gumbel_min_stanvars(), empty = TRUE
  )
  expect_s3_class(fit, "brmsfit")
  expect_true(grepl("gumbel_min_lcdf", fit$model, fixed = TRUE))
})
