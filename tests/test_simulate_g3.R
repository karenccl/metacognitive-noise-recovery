library(testthat)

source(here::here("code", "01_simulate", "simulate_g3_mixture.R"))

test_that("G3 mixture has the right trials per participant x level and a difficulty ordering", {
  skip_if_not_installed("hmetad")
  d <- simulate_g3_mixture(n_participants = 5, n_trials_per_level = 200,
                           dprimes = c(0.5, 2.0), log_M = -1, k = 4, seed = 11)
  tab <- table(d$participant, d$difficulty)
  expect_equal(dim(tab), c(5L, 2L))
  expect_true(all(tab == 200))
  acc <- tapply(d$stimulus == d$response, d$difficulty, mean)
  expect_lt(acc[["L1"]], acc[["L2"]])
  expect_true(all(d$confidence %in% 1:4))
  expect_equal(unique(d$M), exp(-1), tolerance = 1e-8)
})

test_that("G3 control levels share d' but not the random stream", {
  skip_if_not_installed("hmetad")
  d <- simulate_g3_mixture(n_participants = 3, n_trials_per_level = 50,
                           dprimes = c(1.25, 1.25), log_M = -1, k = 4, seed = 11)
  expect_equal(unique(d$dprime_level), 1.25)
  a <- d[d$difficulty == "L1", c("stimulus", "response", "confidence")]
  b <- d[d$difficulty == "L2", c("stimulus", "response", "confidence")]
  expect_false(identical(a, b))
})
