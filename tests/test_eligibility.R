library(testthat)

source(here::here("code", "06_empirical", "eligibility.R"))

test_that("merge_sparse_levels leaves a balanced scale untouched", {
  x <- rep(1:4, each = 25)
  m <- merge_sparse_levels(x, 0.05, 6)
  expect_equal(m$new, 1:4)
})

test_that("a sparse top level merges into its neighbour", {
  x <- c(rep(1, 40), rep(2, 30), rep(3, 28), rep(4, 2))   # level 4 = 2%
  m <- merge_sparse_levels(x, 0.05, 6)
  expect_equal(m$new, c(1L, 2L, 3L, 3L))
})

test_that("a sparse middle level merges into its sparser neighbour", {
  x <- c(rep(1, 50), rep(2, 20), rep(3, 3), rep(4, 27))   # level 3 = 3%; 2 is sparser than 4
  m <- merge_sparse_levels(x, 0.05, 6)
  expect_equal(m$new, c(1L, 2L, 2L, 3L))
})

test_that("k_max is respected and mapping is monotone", {
  x <- rep(1:10, each = 10)
  m <- merge_sparse_levels(x, 0.05, 6)
  expect_lte(max(m$new), 6)
  expect_true(all(diff(m$new) >= 0))
  expect_equal(nrow(m), 10)
})

test_that("harmonise codes stimulus/response on the same mapping", {
  e <- list(min_trials_per_participant = 1, accuracy_range = c(0, 1),
            merge_min_prop = 0, k_max = 6)
  d <- data.frame(Subj_idx = 1, Stimulus = c("L", "R", "R"), Response = c("L", "L", "R"),
                  Confidence = c(1, 2, 3))
  h <- harmonise_dataset(d, e)
  expect_equal(h$data$stimulus, c(0L, 1L, 1L))
  expect_equal(h$data$response, c(0L, 0L, 1L))
  expect_equal(h$data$correct,  c(1L, 0L, 1L))
  expect_equal(h$K, 3)
  expect_equal(as.character(h$data$condition), rep("L1", 3))
})

test_that("harmonise applies participant exclusions and condition labels", {
  e <- list(min_trials_per_participant = 4, accuracy_range = c(0.55, 0.95),
            merge_min_prop = 0, k_max = 6)
  d <- data.frame(Subj_idx = rep(c("a", "b", "c"), c(10, 10, 2)),
                  Stimulus = 1, Response = c(rep(1, 7), rep(2, 3), rep(1, 10), 1, 1),
                  Confidence = rep(1:2, 11), Contrast = rep(c(0.1, 0.2), 11))
  d$Stimulus[1] <- 2; d$Response[1] <- 2           # both stimulus levels present
  d$Accuracy <- as.integer(d$Stimulus == d$Response)
  h <- harmonise_dataset(d, e, difficulty_col = "Contrast")
  # a: 7/10 correct (kept); b: 10/10 (> 0.95, excluded); c: 2 trials (excluded).
  expect_equal(h$n_participants_raw, 3)
  expect_equal(h$n_participants_kept, 1)
  expect_equal(unique(h$data$subj_raw), "a")
  expect_equal(h$condition_map$raw, c("0.1", "0.2"))
  expect_equal(h$acc_agreement, 1)
})

test_that("auto rules reject continuous confidence and non-binary tasks", {
  e <- list(conf_levels_range = list(3, 11), min_participants = 1)
  s <- tibble::tibble(has_required = TRUE, n_stim = c(2, 3, 2), n_resp = c(2, 3, 2),
                      resp_in_stim = TRUE, conf_numeric = c(TRUE, TRUE, FALSE),
                      n_conf_levels = c(50, 4, 4), n_subj_min_trials = 10)
  r <- apply_auto_rules(s, e)
  expect_false(any(r$auto_eligible))
})

test_that("auto rules accept a clean dataset and handle missing required columns", {
  e <- list(conf_levels_range = list(3, 11), min_participants = 20)
  s <- dplyr::bind_rows(
    tibble::tibble(has_required = TRUE, n_stim = 2, n_resp = 2, resp_in_stim = TRUE,
                   conf_numeric = TRUE, n_conf_levels = 4, n_subj_min_trials = 25),
    tibble::tibble(has_required = TRUE, n_stim = 2, n_resp = 2, resp_in_stim = TRUE,
                   conf_numeric = TRUE, n_conf_levels = 6, n_subj_min_trials = 25),
    tibble::tibble(has_required = FALSE))
  r <- apply_auto_rules(s, e)
  expect_equal(r$auto_eligible, c(TRUE, TRUE, FALSE))   # 2nd: e.g. ratings 0.5, 0.6, ..., 1
})

test_that("screen_raw summarises a raw dataset", {
  d <- data.frame(Subj_idx = rep(1:3, each = 4), Stimulus = rep(1:2, 6),
                  Response = rep(c(1, 2, 2, 1), 3), Confidence = rep(1:4, 3),
                  Condition = rep(c("x", "y"), 6))
  s <- screen_raw(d, min_trials = 4)
  expect_true(s$has_required)
  expect_equal(s$n_subj, 3)
  expect_equal(s$n_subj_min_trials, 3)
  expect_equal(s$n_conf_levels, 4)
  expect_true(s$conf_integer)
  expect_equal(s$n_condition, 2)
  expect_false(screen_raw(d[, -1], 4)$has_required)
})

test_that("standardise_names renames case variants and subject_id, but not per-task columns", {
  d <- data.frame(subject_id = 1, stimulus = 1, Response = 1, confidence = 1, accuracy = 1)
  expect_equal(names(standardise_names(d)), c("Subj_idx", "Stimulus", "Response", "Confidence", "Accuracy"))
  d2 <- data.frame(Subj_idx = 1, Stimulus_1 = 1, Response_1 = 1, Confidence_1 = 1)
  expect_equal(names(standardise_names(d2)), names(d2))
  d3 <- data.frame(Subj_idx = 1, stimulus = 1, Stimulus = 2, Response = 1, Confidence = 1)
  expect_equal(names(standardise_names(d3)), names(d3))    # standard name present: untouched
})

test_that("filter_rows drops practice rows, filtered rows and invalid confidence codes", {
  d <- data.frame(Subj_idx = 1, Stimulus = 1, Response = 1,
                  Confidence = c(1, 2, 999, 0, 3, 4), Training = c(1, 0, 0, 0, 0, 0),
                  Catch_trial = c(0, 0, 0, 0, 1, 0))
  f <- filter_rows(d, exclude_filter = "Catch_trial == 1", conf_range = c(1, 4))
  expect_equal(f$Confidence, c(2, 4))
  expect_equal(attr(f, "n_rows_filtered"), 4)
  expect_equal(nrow(filter_rows(d[, -5])), 6)          # no Training column, no filters
})

test_that("rank_within_subject recodes per-participant calibrated levels", {
  e <- list(min_trials_per_participant = 1, accuracy_range = c(0, 1),
            merge_min_prop = 0, k_max = 6)
  d <- data.frame(Subj_idx = rep(1:2, each = 4), Stimulus = rep(1:2, 4), Response = rep(1:2, 4),
                  Confidence = rep(1:4, 2), Difficulty = c(10, 20, 10, 20, 7, 3, 7, 3))
  h <- harmonise_dataset(d, e, difficulty_col = "Difficulty", rank_within_subject = TRUE)
  expect_equal(h$condition_map$raw, c("1", "2"))
  expect_equal(as.character(h$data$condition), c("L1", "L2", "L1", "L2", "L2", "L1", "L2", "L1"))
})

test_that("max_participants keeps a reproducible seeded subsample", {
  e <- list(min_trials_per_participant = 1, accuracy_range = c(0, 1), merge_min_prop = 0, k_max = 6)
  d <- data.frame(Subj_idx = rep(1:10, each = 4), Stimulus = rep(1:2, 20), Response = rep(1:2, 20),
                  Confidence = rep(1:4, 10))
  h1 <- harmonise_dataset(d, e, max_participants = 4, seed = 7)
  h2 <- harmonise_dataset(d, e, max_participants = 4, seed = 7)
  expect_equal(h1$n_participants_after_exclusions, 10)
  expect_equal(h1$n_participants_kept, 4)
  expect_equal(sort(unique(h1$data$participant)), 1:4)
  expect_identical(h1$data, h2$data)
  expect_equal(harmonise_dataset(d, e)$n_participants_kept, 10)
})
