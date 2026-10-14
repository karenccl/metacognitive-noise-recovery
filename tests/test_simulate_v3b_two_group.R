library(testthat)

source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
source(here::here("code", "01_simulate", "simulate_v3b_two_group.R"))

test_that("two groups, unique participant ids, balanced sizes", {
  skip_if_not_installed("hmetad")
  d <- simulate_two_group_g2(5, 40, c(A = 0.75, B = 1.5), log_M = -1, seed = 11)
  expect_setequal(levels(d$group), c("A", "B"))
  ids <- tapply(d$participant, d$group, function(x) sort(unique(x)))
  expect_length(intersect(ids$A, ids$B), 0)
  expect_equal(length(unique(d$participant)), 10)
})

test_that("the high-d' group is more accurate", {
  skip_if_not_installed("hmetad")
  d <- simulate_two_group_g2(20, 200, c(A = 0.75, B = 1.5), log_M = -1, seed = 12)
  acc <- tapply(d$stimulus == d$response, d$group, mean)
  expect_gt(acc[["B"]], acc[["A"]])
})
