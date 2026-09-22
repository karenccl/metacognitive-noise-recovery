library(testthat)

source(here::here("code", "01_simulate", "discretise_confidence.R"))
source(here::here("code", "01_simulate", "simulate_g1_ddm.R"))

sim_small <- function(n_participants = 5, n_trials = 100, sigma_c = 0.5, seed = 42, ...) {
  simulate_g1_ddm(
    n_participants = n_participants, n_trials = n_trials,
    v = 1.2, a = 1.5, t0 = 0.3, tau = 0.3, sigma_c = sigma_c,
    seed = seed, ...
  )
}

test_that("simulate_g1_ddm output has one row per trial, valid confidence range", {
  d <- sim_small(n_participants = 5, n_trials = 100)

  expect_equal(nrow(d), 500)
  expect_true(all(d$confidence %in% 1:4))
  expect_true(all(d$stimulus %in% 0:1))
  expect_true(all(d$response %in% 0:1))
  expect_equal(d$correct, as.integer(d$stimulus == d$response))
  expect_true(all(d$rt > d$t0))
  expect_true(all(c("participant", "trial", "stimulus", "response", "correct",
                     "rt", "q", "y", "confidence", "v", "a", "t0", "tau",
                     "sigma_c", "seed") %in% names(d)))
})

test_that("at sigma_c = 0, confidence is monotonic (non-decreasing) in q per subject", {
  d <- sim_small(n_participants = 3, n_trials = 200, sigma_c = 0)

  expect_equal(d$y, d$q)
  for (p in unique(d$participant)) {
    sub <- d[d$participant == p, ]
    ord <- order(sub$q)
    expect_false(is.unsorted(sub$confidence[ord]))
  }
})

test_that("at large sigma_c, rank correlation between y and q approaches zero", {
  d <- sim_small(n_participants = 3, n_trials = 3000, sigma_c = 50, seed = 9)

  r <- cor(d$q, d$y, method = "spearman")
  expect_lt(abs(r), 0.1)

  # category proportions remain nondegenerate (rank-based binning
  # guarantees ~equal marginal counts by construction, see
  # docs/design_decisions.md)
  counts <- table(d$confidence)
  expect_equal(length(counts), 4L)
  expect_true(all(counts > 0))
})

test_that("stimulus/response/confidence data can pass the aggregation function", {
  skip_if_not_installed("hmetad")
  d <- sim_small(n_participants = 5, n_trials = 100)
  agg <- hmetad::aggregate_metad(d, K = 4)
  expect_equal(nrow(agg), 1)
})

test_that("same inputs and seed return identical output", {
  d1 <- sim_small(seed = 123)
  d2 <- sim_small(seed = 123)
  expect_identical(d1, d2)

  d3 <- sim_small(seed = 456)
  expect_false(identical(d1$y, d3$y))
})
