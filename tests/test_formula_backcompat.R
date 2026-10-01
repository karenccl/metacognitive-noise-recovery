library(testthat)

source(here::here("code", "02_fit", "fit_hmetad.R"))
ref <- readRDS(here::here("tests", "fixtures", "formula_k4_v121.rds"))

test_that("default formula and priors are unchanged from v1.2.1", {
  skip_if_not_installed("hmetad")
  expect_identical(capture.output(print(.build_metad_formula(4))), ref$k4)
  expect_identical(capture.output(print(.build_metad_formula(4, hierarchical_dprime_c = FALSE))), ref$k4_nohier)
  expect_identical(capture.output(print(.build_metad_formula(4, hierarchical_thresholds = TRUE))), ref$k4_thr)
  expect_identical(capture.output(print(.build_metad_priors(4, "normal(0, 1)", "normal(0, 1)"))), ref$pri_k4)
})

test_that("covariates enter the intended parts of the formula", {
  skip_if_not_installed("hmetad")
  f <- capture.output(print(.build_metad_formula(4, dprime_c_covariates = "difficulty")))
  expect_true(any(grepl("^dprime ~ 1 \\+ difficulty \\+ \\(1 \\| participant\\)", f)))
  expect_true(any(grepl("^c ~ 1 \\+ difficulty \\+ \\(1 \\| participant\\)", f)))
  expect_true(any(grepl("^N ~ 1 \\+ \\(1 \\| participant\\)", f)))
  g <- capture.output(print(.build_metad_formula(4, log_M_covariates = "condition")))
  expect_true(any(grepl("^N ~ 1 \\+ condition \\+ \\(1 \\| participant\\)", g)))
  expect_true(any(grepl("^dprime ~ 1 \\+ \\(1 \\| participant\\)", g)))
})

test_that("log_M_b_prior adds exactly one class-b prior", {
  skip_if_not_installed("hmetad")
  p0 <- .build_metad_priors(4, "normal(0, 1)", "normal(0, 1)")
  p1 <- .build_metad_priors(4, "normal(0, 1)", "normal(0, 1)", log_M_b_prior = "normal(0, 1)")
  expect_equal(nrow(p1), nrow(p0) + 1)
  expect_equal(sum(p1$class == "b" & p1$dpar == ""), 1)
})

test_that("fit_one_hmetad rejects covariates that are not aggregation columns", {
  skip_if_not_installed("hmetad")
  source(here::here("code", "01_simulate", "simulate_g0.R"))
  d <- simulate_g0(n_participants = 3, n_trials = 20, dprime_target = 1, log_M = -1, seed = 1)
  expect_error(fit_one_hmetad(d, K = 4, dprime_c_covariates = "difficulty", seed = 1), "agg_by")
  expect_error(fit_one_hmetad(d, K = 4, agg_by = "difficulty", seed = 1), "not in data")
})

test_that("covariate formulas build an (empty) brmsfit, including gumbel_min and a log_M covariate", {
  skip_if_not_installed("hmetad")
  source(here::here("code", "01_simulate", "simulate_g0.R"))
  source(here::here("code", "01_simulate", "simulate_g2_gumbel.R"))
  d <- simulate_g0(n_participants = 4, n_trials = 40, dprime_target = 1, log_M = -1, seed = 1)
  d$condition <- factor(rep(c("L1", "L2"), length.out = nrow(d)))
  agg <- hmetad::aggregate_metad(d, participant, condition, K = 4)
  f <- .build_metad_formula(4, dprime_c_covariates = "condition", log_M_covariates = "condition",
                            hierarchical_thresholds = TRUE)
  p <- .build_metad_priors(4, "normal(0, 1)", "normal(0, 1)", log_M_b_prior = "normal(0, 1)")
  fit <- hmetad::fit_metad(f, agg, aggregate = FALSE, K = 4, prior = p,
                           distribution = "gumbel_min", stanvars = gumbel_min_stanvars(), empty = TRUE)
  expect_s3_class(fit, "brmsfit")
  expect_true(grepl("gumbel_min_lcdf", fit$model, fixed = TRUE))
})

test_that("sd_prior adds one class-sd prior per hierarchical part and builds", {
  skip_if_not_installed("hmetad")
  p0 <- .build_metad_priors(4, "normal(0, 1)", "normal(0, 1)")
  p1 <- .build_metad_priors(4, "normal(0, 1)", "normal(0, 1)", sd_prior = "normal(0, 0.5)")
  expect_equal(nrow(p1), nrow(p0) + 3)                      # mu, dprime, c
  p2 <- .build_metad_priors(4, "normal(0, 1)", "normal(0, 1)", sd_prior = "normal(0, 0.5)",
                            hierarchical_thresholds = TRUE)
  expect_equal(nrow(p2), nrow(p0) + 3 + length(hmetad::metac2_parameters(4)))
  source(here::here("code", "01_simulate", "simulate_g0.R"))
  d <- simulate_g0(n_participants = 4, n_trials = 40, dprime_target = 1, log_M = -1, seed = 1)
  agg <- hmetad::aggregate_metad(d, participant, K = 4)
  fit <- hmetad::fit_metad(.build_metad_formula(4, hierarchical_thresholds = TRUE), agg,
                           aggregate = FALSE, K = 4, prior = p2, empty = TRUE)
  ps <- brms::prior_summary(fit)
  expect_true(all(ps$prior[ps$class == "sd" & ps$source == "user"] == "normal(0, 0.5)"))
  expect_false(any(ps$prior[ps$class == "sd"] == "student_t(3, 0, 2.5)"))
})
