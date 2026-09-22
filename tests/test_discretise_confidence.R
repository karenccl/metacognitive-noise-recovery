library(testthat)

source(here::here("code", "01_simulate", "discretise_confidence.R"))

make_test_data <- function(n_participants = 3, n_per = 20, seed = 1) {
  withr::with_seed(seed, {
    tibble::tibble(
      participant = rep(seq_len(n_participants), each = n_per),
      y = stats::rnorm(n_participants * n_per)
    )
  })
}

test_that("discretise_confidence returns K categories per subject with ~equal counts", {
  d <- make_test_data(n_participants = 4, n_per = 40)
  res <- discretise_confidence(d, "participant", "y", k = 4)

  expect_true(all(res$data$confidence %in% 1:4))
  counts <- res$category_counts
  expect_equal(sort(unique(counts$confidence)), 1:4)
  # ntile on 40 trials / 4 bins gives exactly 10 per bin
  expect_true(all(counts$n == 10))
})

test_that("discretise_confidence output preserves row count and columns", {
  d <- make_test_data(n_participants = 3, n_per = 20)
  res <- discretise_confidence(d, "participant", "y", k = 4)

  expect_equal(nrow(res$data), nrow(d))
  expect_true(all(c("participant", "y", "confidence") %in% names(res$data)))
  expect_equal(nrow(res$cutpoints), dplyr::n_distinct(d$participant))
})

test_that("discretise_confidence works for K = 6 (binning sensitivity analysis)", {
  d <- make_test_data(n_participants = 2, n_per = 60)
  res <- discretise_confidence(d, "participant", "y", k = 6)
  expect_equal(sort(unique(res$data$confidence)), 1:6)
})

test_that("discretise_confidence flags tied values and degenerate cutpoints", {
  d <- tibble::tibble(participant = rep(1L, 20), y = rep(c(0, 1), 10))
  res <- discretise_confidence(d, "participant", "y", k = 4)

  expect_equal(res$tie_summary$total_duplicate_values, 20L)
  expect_gt(res$tie_summary$total_degenerate_cutpoints, 0L)
})

test_that("discretise_confidence errors on missing columns or NA values", {
  d <- make_test_data()
  expect_error(discretise_confidence(d, "nope", "y", k = 4))
  expect_error(discretise_confidence(d, "participant", "nope", k = 4))

  d_na <- d
  d_na$y[1] <- NA_real_
  expect_error(discretise_confidence(d_na, "participant", "y", k = 4))
})
