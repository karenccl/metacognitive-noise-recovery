# v3 step 3 summary (docs/v3_plan.md §4.6-4.7): G3 difficulty-mixture results.
# ELPD sign follows config/v3.yml: elpd_diff = elpd(normal) - elpd(gumbel_min),
# > 0 favours Gaussian. Comparisons are only within an aggregation (pooled vs
# pooled, difficulty vs difficulty): the two aggregations are different data.
# Applies the pre-specified artefact rule (config/v3.yml g3$artefact_rule,
# tag v3-prereg-g3) to the pooled comparisons.
#
# Run from the project root: Rscript code/04_ppc_and_comparison/v3_g3_summary.R

suppressPackageStartupMessages(library(dplyr))
cfg  <- yaml::read_yaml(here::here("config", "design.yml"))
cfg3 <- yaml::read_yaml(here::here("config", "v3.yml"))
out  <- here::here("data", "processed", "v3")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

recs <- purrr::map(list.files(here::here("data", "interim", "v3_g3"), "[.]qs2$", full.names = TRUE),
                   qs2::qs_read)
grid <- readr::read_csv(here::here("config", "grid_g3.csv"), show_col_types = FALSE)
stopifnot(length(recs) == nrow(grid))

by_fit <- purrr::map_dfr(recs, function(r) {
  x <- if (!is.null(r$draws_b_sd)) r$draws_b_sd$b_Intercept else NA_real_
  tibble::tibble(g3_id = r$g3_id, status = r$status,
                 escalated = if (is.null(r$escalated)) NA else r$escalated,
                 log_M_mean = mean(x), log_M_q025 = quantile(x, .025, names = FALSE, na.rm = TRUE),
                 log_M_q975 = quantile(x, .975, names = FALSE, na.rm = TRUE),
                 has_loo = !is.null(r$loo),
                 n_bad_k = if (is.null(r$loo)) NA_integer_
                           else sum(r$loo$diagnostics$pareto_k > cfg3$loo_robust$k_threshold),
                 n_loo_obs = if (is.null(r$loo)) NA_integer_ else nrow(r$loo$pointwise))
}) |> left_join(grid, by = "g3_id") |>
  mutate(bias = log_M_mean - cfg$truth$log_M,
         covered = log_M_q025 <= cfg$truth$log_M & cfg$truth$log_M <= log_M_q975) |>
  arrange(g3_id)
readr::write_csv(by_fit, file.path(out, "g3_by_fit.csv"))

loo_of <- setNames(purrr::map(recs, "loo"), purrr::map_int(recs, "g3_id"))

# elpd(normal) - elpd(gumbel); > 0 favours Gaussian (v3 sign convention)
cmp_family <- function(id_normal, id_gumbel) {
  a <- loo_of[[as.character(id_normal)]]; b <- loo_of[[as.character(id_gumbel)]]
  if (is.null(a) || is.null(b)) return(c(diff = NA_real_, se = NA_real_))
  cmp <- loo::loo_compare(list(normal = a, gumbel = b))
  c(diff = cmp["normal", "elpd_diff"] - cmp["gumbel", "elpd_diff"], se = max(cmp[, "se_diff"]))
}

loo_tbl <- grid |>
  mutate(agg = if_else(grepl("pooled", fit_variant), "pooled", "difficulty"),
         fam = sub("_.*", "", fit_variant)) |>
  select(condition, rep_id, agg, fam, g3_id) |>
  tidyr::pivot_wider(names_from = fam, values_from = g3_id, names_prefix = "id_") |>
  rowwise() |>
  mutate(res = list(cmp_family(id_normal, id_gumbel))) |>
  ungroup() |>
  mutate(elpd_diff = purrr::map_dbl(res, "diff"), se = purrr::map_dbl(res, "se"),
         favors_gumbel_2se = elpd_diff < -2 * se,
         favors_normal_2se = elpd_diff > 2 * se) |>
  select(-res)
readr::write_csv(loo_tbl, file.path(out, "g3_loo_by_rep.csv"))

rates <- loo_tbl |>
  group_by(condition, agg) |>
  summarise(n = n(), n_missing = sum(is.na(elpd_diff)),
            prop_favors_gumbel_2se = mean(favors_gumbel_2se, na.rm = TRUE),
            prop_favors_normal_2se = mean(favors_normal_2se, na.rm = TRUE),
            prop_favors_gumbel = mean(elpd_diff < 0, na.rm = TRUE),
            mean_elpd_diff = mean(elpd_diff, na.rm = TRUE),
            median_elpd_diff = median(elpd_diff, na.rm = TRUE), .groups = "drop")
readr::write_csv(rates, file.path(out, "g3_loo_rates.csv"))
print(as.data.frame(rates), digits = 3)

# Pre-specified verdict (config/v3.yml g3$artefact_rule), pooled comparisons only
r_mix <- rates$prop_favors_gumbel_2se[rates$condition == "mixture" & rates$agg == "pooled"]
r_con <- rates$prop_favors_gumbel_2se[rates$condition == "control" & rates$agg == "pooled"]
verdict <- if (r_mix >= cfg3$g3$artefact_rule$mixture_min_prop &&
               r_con <= cfg3$g3$artefact_rule$control_max_prop) "pooling artefact present" else
           "no pooling artefact by the pre-specified rule"
cat(sprintf("\nG3 verdict: %s (pooled, favours Gumbel > 2 SE: mixture %.2f, control %.2f)\n",
            verdict, r_mix, r_con))
writeLines(sprintf("%s\nmixture_pooled_prop_favors_gumbel_2se = %.3f\ncontrol_pooled_prop_favors_gumbel_2se = %.3f",
                   verdict, r_mix, r_con), file.path(out, "g3_verdict.txt"))

bias_tbl <- by_fit |>
  group_by(condition, fit_variant) |>
  summarise(n = n(), bias = mean(bias, na.rm = TRUE),
            mcse = sd(log_M_mean, na.rm = TRUE) / sqrt(sum(!is.na(log_M_mean))),
            coverage = mean(covered, na.rm = TRUE), n_not_pass = sum(status != "pass"),
            n_escalated = sum(escalated, na.rm = TRUE),
            prop_fits_bad_k = mean(n_bad_k > 0, na.rm = TRUE), .groups = "drop")
readr::write_csv(bias_tbl, file.path(out, "g3_bias.csv"))
print(as.data.frame(bias_tbl), digits = 3)

# Plan §4.7 check: paired delta log_M (normal - gumbel) on the same dataset,
# per aggregation. Data are Gaussian, so the difficulty version should be ~0.
delta_tbl <- by_fit |>
  mutate(agg = if_else(grepl("pooled", fit_variant), "pooled", "difficulty"),
         fam = sub("_.*", "", fit_variant)) |>
  select(condition, rep_id, agg, fam, log_M_mean) |>
  tidyr::pivot_wider(names_from = fam, values_from = log_M_mean) |>
  mutate(delta_logM = normal - gumbel) |>
  group_by(condition, agg) |>
  summarise(n = sum(!is.na(delta_logM)), mean_delta = mean(delta_logM, na.rm = TRUE),
            mcse = sd(delta_logM, na.rm = TRUE) / sqrt(n), .groups = "drop")
readr::write_csv(delta_tbl, file.path(out, "g3_delta_logM.csv"))
print(as.data.frame(delta_tbl), digits = 3)
cat("\nWrote data/processed/v3/g3_*.csv and g3_verdict.txt\n")
