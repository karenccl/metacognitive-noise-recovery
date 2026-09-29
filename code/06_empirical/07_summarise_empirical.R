# v3 empirical step 5.10 (docs/v3_plan.md): pre-specified per-dataset summary.
# elpd_diff = elpd(normal) - elpd(gumbel_min), > 0 favours Gaussian (config/v3.yml
# sign convention), from the repaired LOO (reloo or grouped K-fold). Categories:
#   unreliable      either fit not "pass", or LOO repair failed
#   clear_gaussian  elpd_diff >  2 SE
#   clear_gumbel    elpd_diff < -2 SE
#   inconclusive    otherwise
# delta_logM = log_M(normal) - log_M(gumbel), same sign as the simulation delta_mis.
#
# Run from the project root: Rscript code/06_empirical/07_summarise_empirical.R

suppressPackageStartupMessages(library(dplyr))
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml")); e <- cfg3$empirical
fit_dir <- here::here("data", "interim", "v3_empirical", "fits")
rep_dir <- here::here("data", "interim", "v3_empirical", "loo_repaired")
out <- here::here("data", "processed", "v3", "empirical")
sel <- readr::read_csv(file.path(out, "selected_datasets.csv"), show_col_types = FALSE)
prep_log <- readr::read_csv(file.path(out, "prepare_log.csv"), show_col_types = FALSE)

# Condition-level log_M draws: L1 = intercept, Lk = intercept + b_conditionLk.
logM_levels <- function(draws, labels) {
  sapply(labels, function(l) {
    nm <- paste0("b_condition", l)
    if (nm %in% names(draws)) draws$b_Intercept + draws[[nm]] else draws$b_Intercept
  })
}

one_dataset <- function(ds) {
  f <- purrr::map(c(normal = "normal", gumbel = "gumbel_min"),
                  ~ qs2::qs_read(file.path(fit_dir, sprintf("%s__%s.qs2", ds, .x))))
  r <- purrr::map(c(normal = "normal", gumbel = "gumbel_min"), function(x) {
    p <- file.path(rep_dir, sprintf("%s__%s.qs2", ds, x))
    if (file.exists(p)) qs2::qs_read(p) else list(ok = FALSE, method = NA_character_)
  })
  statuses <- purrr::map_chr(f, "status")
  repaired_ok <- all(purrr::map_lgl(r, "ok"))

  # elpd(normal) - elpd(gumbel): > 0 favours Gaussian
  if (repaired_ok) {
    cmp <- loo::loo_compare(list(normal = r$normal$loo_repaired, gumbel = r$gumbel$loo_repaired))
    diff <- cmp["normal", "elpd_diff"] - cmp["gumbel", "elpd_diff"]; se <- max(cmp[, "se_diff"])
  } else { diff <- NA_real_; se <- NA_real_ }
  # Unrepaired PSIS comparison, for reference only.
  psis <- if (!is.null(f$normal$loo) && !is.null(f$gumbel$loo)) {
    cp <- loo::loo_compare(list(normal = f$normal$loo, gumbel = f$gumbel$loo))
    c(cp["normal", "elpd_diff"] - cp["gumbel", "elpd_diff"], max(cp[, "se_diff"]))
  } else c(NA_real_, NA_real_)

  category <- dplyr::case_when(
    any(!statuses %in% c("pass")) | !repaired_ok ~ "unreliable",
    diff >  e$categories$two_se_rule * se ~ "clear_gaussian",
    diff < -e$categories$two_se_rule * se ~ "clear_gumbel",
    TRUE ~ "inconclusive")

  labels <- f$normal$condition_map$label
  has_draws <- !is.null(f$normal$draws_b_sd) && !is.null(f$gumbel$draws_b_sd)
  if (has_draws) {
    LN <- as.matrix(logM_levels(f$normal$draws_b_sd, labels))
    LG <- as.matrix(logM_levels(f$gumbel$draws_b_sd, labels))
    colnames(LN) <- colnames(LG) <- labels
    overall_N <- rowMeans(LN); overall_G <- rowMeans(LG)
  }

  base <- tibble::tibble(
    dataset = ds, method = r$normal$method, status_normal = statuses[["normal"]],
    status_gumbel = statuses[["gumbel"]],
    prop_bad_k_normal = if (is.null(r$normal$prop_bad_k)) NA_real_ else r$normal$prop_bad_k,
    prop_bad_k_gumbel = if (is.null(r$gumbel$prop_bad_k)) NA_real_ else r$gumbel$prop_bad_k,
    elpd_diff = diff, se = se, elpd_diff_psis = psis[1], se_psis = psis[2], category = category,
    logM_normal = if (has_draws) mean(overall_N) else NA_real_,
    logM_gumbel = if (has_draws) mean(overall_G) else NA_real_,
    delta_logM  = if (has_draws) mean(overall_N) - mean(overall_G) else NA_real_,
    delta_logM_q025 = if (has_draws) quantile(overall_N - overall_G, .025, names = FALSE) else NA_real_,
    delta_logM_q975 = if (has_draws) quantile(overall_N - overall_G, .975, names = FALSE) else NA_real_,
    n_levels = length(labels))

  contrasts <- if (has_draws && length(labels) > 1) purrr::map_dfr(labels[-1], function(l) {
    cN <- LN[, l] - LN[, labels[1]]; cG <- LG[, l] - LG[, labels[1]]
    excl <- function(x) { q <- quantile(x, c(.025, .975)); q[[1]] > 0 | q[[2]] < 0 }
    tibble::tibble(dataset = ds, contrast = paste(l, "-", labels[1]),
                   raw_level = f$normal$condition_map$raw[f$normal$condition_map$label == l],
                   contrast_normal = mean(cN), contrast_gumbel = mean(cG),
                   change = mean(cN) - mean(cG),
                   excl0_normal = excl(cN), excl0_gumbel = excl(cG),
                   conclusion_flip = excl(cN) != excl(cG))
  }) else NULL
  list(base = base, contrasts = contrasts)
}

ds_list <- sort(unique(sub("__.*$", "", list.files(fit_dir, "[.]qs2$"))))
res <- purrr::map(ds_list, one_dataset)
ppc <- readr::read_csv(file.path(out, "ppc_by_fit.csv"), show_col_types = FALSE)
ppc_w <- ppc |>
  mutate(family = if_else(family == "normal", "normal", "gumbel")) |>
  select(dataset, family, p_stat1_rmse, p_stat2_highconf, p_stat3_x2_df) |>
  tidyr::pivot_wider(names_from = family, values_from = starts_with("p_stat"))
by_ds <- purrr::map_dfr(res, "base") |>
  left_join(select(sel, dataset, set, category_db = category, difficulty_design), by = "dataset") |>
  left_join(select(prep_log, dataset, K, n_cond, n_participants_kept, n_trials), by = "dataset") |>
  left_join(ppc_w, by = "dataset")
contr <- purrr::map_dfr(res, "contrasts")

readr::write_csv(by_ds, file.path(out, "empirical_by_dataset.csv"))
readr::write_csv(contr, file.path(out, "empirical_condition_contrasts.csv"))

summary_tbl <- by_ds |> count(set, category) |> group_by(set) |> mutate(prop = n / sum(n)) |> ungroup()
readr::write_csv(summary_tbl, file.path(out, "empirical_category_summary.csv"))
print(as.data.frame(summary_tbl), digits = 3)
cat("\nMedian delta_logM (normal - gumbel) by set:\n")
print(as.data.frame(by_ds |> group_by(set) |>
  summarise(n = n(), median_delta = median(delta_logM, na.rm = TRUE),
            prop_delta_pos = mean(delta_logM > 0, na.rm = TRUE), .groups = "drop")), digits = 3)
if (nrow(contr)) cat("\nCondition contrasts with a conclusion flip:", sum(contr$conclusion_flip), "of", nrow(contr), "\n")
