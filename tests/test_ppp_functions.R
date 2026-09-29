library(testthat)

source(here::here("code", "04_ppc_and_comparison", "ppp_functions.R"))

test_that("make_col_map(4) reproduces the hard-coded K = 4 layout", {
  ref <- tibble::tribble(
    ~stimulus, ~response, ~confidence, ~col,
    0, 0, 4, 1,  0, 0, 3, 2,  0, 0, 2, 3,  0, 0, 1, 4,
    0, 1, 1, 5,  0, 1, 2, 6,  0, 1, 3, 7,  0, 1, 4, 8,
    1, 0, 4, 9,  1, 0, 3, 10, 1, 0, 2, 11, 1, 0, 1, 12,
    1, 1, 1, 13, 1, 1, 2, 14, 1, 1, 3, 15, 1, 1, 4, 16)
  got <- make_col_map(4)
  expect_equal(as.data.frame(lapply(got, as.numeric)), as.data.frame(lapply(ref, as.numeric)))
})

test_that("make_col_map matches aggregate_metad's column layout for K = 3 and 6", {
  skip_if_not_installed("hmetad")
  for (K in c(3L, 6L)) {
    d <- expand.grid(participant = 1L, confidence = seq_len(K), response = 0:1, stimulus = 0:1)
    d <- d[rep(seq_len(nrow(d)), seq_len(nrow(d))), ]      # distinct count per cell
    agg <- hmetad::aggregate_metad(d, participant, K = K)
    m <- make_col_map(K)
    expected <- vapply(seq_len(nrow(m)), function(i)
      sum(d$stimulus == m$stimulus[i] & d$response == m$response[i] & d$confidence == m$confidence[i]),
      numeric(1))
    expect_equal(as.numeric(agg$N[1, m$col]), expected)
  }
})

test_that("generalised PPP reproduces the stored v2 p-values on stored G2 fits", {
  skip_if_not_installed("hmetad")
  files <- sort(list.files(here::here("data", "interim"),
                           pattern = "^g2_.*_rep-0[12]_.*[.]qs2$", full.names = TRUE))
  skip_if(length(files) < 2, "stored G2 full fits not available")
  source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
  seed_base <- yaml::read_yaml(here::here("config", "design.yml"))$seed_base
  ref <- readr::read_csv(here::here("data", "processed", "v2", "g2_ppp_by_fit.csv"), show_col_types = FALSE)
  for (f in files[1:2]) {                          # one correct, one Gaussian fit
    r   <- qs2::qs_read(f)
    got <- ppp_one_fit_general(r$fit, r$agg, K = 4, group_cols = "participant",
                               seed = seed_base + r$grid_id)
    exp <- ref[ref$grid_id == r$grid_id, ]
    expect_equal(got$p_stat1_rmse,     exp$p_stat1_rmse,     tolerance = 1e-12)
    expect_equal(got$p_stat2_highconf, exp$p_stat2_highconf, tolerance = 1e-12)
    expect_equal(got$p_stat3_x2_df,    exp$p_stat3_x2_df,    tolerance = 1e-12)
    expect_equal(got$mean_obs_stat1,   exp$mean_obs_stat1,   tolerance = 1e-12)
  }
})
