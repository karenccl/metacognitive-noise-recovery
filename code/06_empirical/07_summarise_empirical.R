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
source(here::here("code", "06_empirical", "loo_repair_functions.R"))
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

  # EXPLORATORY sensitivity (config/v3.yml exploratory$divergence_only_sensitivity;
  # pre-specified 2026-10-02 before any LOO was read). A fit counts as usable here
  # if it passed, or if it failed ONLY on divergences (R-hat and bulk/tail ESS
  # within the design.yml limits, no tree-depth hits). The primary category
  # above is unchanged.
  flags_of <- fit_flags; div_only <- divergence_only           # loo_repair_functions.R
  usable_sens <- purrr::map_lgl(f, conv_ok)
  category_div_sens <- dplyr::case_when(
    !all(usable_sens) | !repaired_ok ~ "unreliable",
    diff >  e$categories$two_se_rule * se ~ "clear_gaussian",
    diff < -e$categories$two_se_rule * se ~ "clear_gumbel",
    TRUE ~ "inconclusive")
  diag_row <- function(fit, fam) {
    fl <- flags_of(fit); d <- fit$diagnostics
    tibble::tibble(dataset = ds, family = fam, status = fit$status,
                   fail_divergences = "divergences" %in% fl, fail_rhat = "rhat" %in% fl,
                   fail_bulk_ess = "bulk_ess" %in% fl, fail_tail_ess = "tail_ess" %in% fl,
                   fail_treedepth = "max_treedepth" %in% fl, divergence_only = div_only(fit),
                   n_divergent = if (is.null(d)) NA_real_ else d$n_divergent,
                   max_rhat = if (is.null(d)) NA_real_ else d$max_rhat,
                   min_ess_bulk = if (is.null(d)) NA_real_ else d$min_ess_bulk,
                   min_ess_tail = if (is.null(d)) NA_real_ else d$min_ess_tail)
  }
  diagnostics <- dplyr::bind_rows(diag_row(f$normal, "normal"), diag_row(f$gumbel, "gumbel_min"))

  labels <- f$normal$condition_map$label
  has_draws <- !is.null(f$normal$draws_b_sd) && !is.null(f$gumbel$draws_b_sd)
  if (has_draws) {
    LN <- as.matrix(logM_levels(f$normal$draws_b_sd, labels))
    LG <- as.matrix(logM_levels(f$gumbel$draws_b_sd, labels))
    colnames(LN) <- colnames(LG) <- labels
    overall_N <- rowMeans(LN); overall_G <- rowMeans(LG)
  }

  # Pre-specified prior check (config/v3.yml sd_prior_check).
  sdq <- function(fit) {
    v <- if (is.null(fit$draws_b_sd)) NULL else fit$draws_b_sd[[e$sd_prior_check$param]]
    if (is.null(v)) c(NA_real_, NA_real_) else c(stats::median(v), stats::quantile(v, .975, names = FALSE))
  }
  sdN <- sdq(f$normal); sdG <- sdq(f$gumbel)

  base <- tibble::tibble(
    dataset = ds, method = r$normal$method, status_normal = statuses[["normal"]],
    status_gumbel = statuses[["gumbel"]],
    prop_bad_k_normal = if (is.null(r$normal$prop_bad_k)) NA_real_ else r$normal$prop_bad_k,
    prop_bad_k_gumbel = if (is.null(r$gumbel$prop_bad_k)) NA_real_ else r$gumbel$prop_bad_k,
    elpd_diff = diff, se = se, elpd_diff_psis = psis[1], se_psis = psis[2], category = category,
    category_div_sens = category_div_sens,
    logM_normal = if (has_draws) mean(overall_N) else NA_real_,
    logM_gumbel = if (has_draws) mean(overall_G) else NA_real_,
    delta_logM  = if (has_draws) mean(overall_N) - mean(overall_G) else NA_real_,
    delta_logM_q025 = if (has_draws) quantile(overall_N - overall_G, .025, names = FALSE) else NA_real_,
    delta_logM_q975 = if (has_draws) quantile(overall_N - overall_G, .975, names = FALSE) else NA_real_,
    n_levels = length(labels),
    sd_logM_median_normal = sdN[1], sd_logM_q975_normal = sdN[2],
    sd_logM_median_gumbel = sdG[1], sd_logM_q975_gumbel = sdG[2],
    flag_sd_prior = any(c(sdN[2], sdG[2]) > e$sd_prior_check$q975_flag_above, na.rm = TRUE))

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
  list(base = base, contrasts = contrasts, diagnostics = diagnostics)
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
cat("\nFits flagged by the pre-specified SD prior check:", sum(by_ds$flag_sd_prior), "of", nrow(by_ds), "datasets\n")
# ---- EXPLORATORY: diagnostic failures by family (pre-specified 2026-10-02) ---
diag_fit <- purrr::map_dfr(res, "diagnostics") |> left_join(select(sel, dataset, set), by = "dataset")
readr::write_csv(diag_fit, file.path(out, "exploratory_diagnostics_by_fit.csv"))
diag_rates <- diag_fit |> group_by(family) |>
  summarise(n_fits = n(), fail_any = mean(status != "pass"),
            fail_divergences = mean(fail_divergences), fail_rhat = mean(fail_rhat),
            fail_bulk_ess = mean(fail_bulk_ess), fail_tail_ess = mean(fail_tail_ess),
            fail_treedepth = mean(fail_treedepth), divergence_only = mean(divergence_only),
            error = mean(status == "error"), .groups = "drop")
readr::write_csv(diag_rates, file.path(out, "exploratory_diagnostics_by_family.csv"))
# Paired: which family failed, within the same dataset.
diag_paired <- diag_fit |> select(dataset, set, family, status) |>
  tidyr::pivot_wider(names_from = family, values_from = status) |>
  mutate(which_failed = case_when(normal == "pass" & gumbel_min == "pass" ~ "neither",
                                  normal != "pass" & gumbel_min == "pass" ~ "gaussian_only",
                                  normal == "pass" & gumbel_min != "pass" ~ "gumbel_only",
                                  TRUE ~ "both"))
paired_tbl <- count(diag_paired, which_failed)
readr::write_csv(diag_paired, file.path(out, "exploratory_diagnostics_paired.csv"))
cat("\n[Exploratory] diagnostic failure rates by family:\n"); print(as.data.frame(diag_rates), digits = 3)
cat("\n[Exploratory] which family failed (paired by dataset):\n"); print(as.data.frame(paired_tbl))
# McNemar-type exact test on the discordant pairs (descriptive only).
b <- sum(diag_paired$which_failed == "gaussian_only"); c_ <- sum(diag_paired$which_failed == "gumbel_only")
if (b + c_ > 0) cat(sprintf("Discordant pairs: Gaussian-only %d, Gumbel-only %d, exact binomial p = %.3f\n",
                            b, c_, stats::binom.test(b, b + c_)$p.value))

# ---- EXPLORATORY: divergence-only sensitivity categories ----------------------
sens_tbl <- by_ds |> count(set, category_div_sens) |> group_by(set) |> mutate(prop = n / sum(n)) |> ungroup()
readr::write_csv(sens_tbl, file.path(out, "exploratory_category_divergence_sensitivity.csv"))
cat("\n[Exploratory] categories when divergence-only failures are admitted:\n"); print(as.data.frame(sens_tbl), digits = 3)

if (nrow(contr)) cat("\nCondition contrasts with a conclusion flip:", sum(contr$conclusion_flip), "of", nrow(contr), "\n")
